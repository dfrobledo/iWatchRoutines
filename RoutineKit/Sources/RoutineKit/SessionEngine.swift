import Foundation

/// Un paso de la sesión guiada: calentamiento, una serie o un descanso.
public struct SessionStep: Equatable, Identifiable, Sendable {
    public enum Side: Sendable {
        case first, second
    }

    public enum Kind: Equatable, Sendable {
        case cardio(CardioActivity, duration: ValueRange)
        case set(Target, number: Int, of: Int, side: Side?)
        /// Descanso que sigue a la serie `afterSet` del mismo bloque.
        case rest(ValueRange, afterSet: Int)
    }

    public let id: Int
    /// Bloque de la rutina al que pertenece (el ejercicio original, aunque se haya cambiado).
    public let blockID: String
    public let title: String
    public let kind: Kind
    public let details: [String]
    public let equipment: [String]

    public var isSet: Bool {
        if case .set = kind { return true }
        return false
    }

    public var isRest: Bool {
        if case .rest = kind { return true }
        return false
    }

    public var setNumber: Int? {
        switch kind {
        case .cardio: return nil
        case .set(_, let number, _, _): return number
        case .rest(_, let afterSet): return afterSet
        }
    }

    public var side: Side? {
        if case .set(_, _, _, let side) = kind { return side }
        return nil
    }

    /// Rango del temporizador; `nil` si no hay tiempo definido.
    public var timerRange: ValueRange? {
        switch kind {
        case .cardio(_, let duration): return duration
        case .rest(let seconds, _): return seconds
        case .set(.time(let seconds), _, _, _): return seconds
        case .set(.reps, _, _, _): return nil
        }
    }

    /// Paso que se mide en tiempo (con rango o como cronómetro abierto).
    public var isTimed: Bool {
        switch kind {
        case .cardio, .rest, .set(.time, _, _, _): return true
        case .set(.reps, _, _, _): return false
        }
    }
}

/// Máquina de estados de una sesión: recorre los pasos de un día y permite
/// cambiar un ejercicio por una de sus alternativas a mitad de la sesión.
public struct SessionEngine: Sendable {
    public let routine: Routine
    public let day: Day
    public private(set) var steps: [SessionStep]
    public private(set) var index = 0
    private var choices: [String: String]

    public init(routine: Routine, day: Day, choices: [String: String] = [:]) {
        self.routine = routine
        self.day = day
        self.choices = choices
        self.steps = SessionPlanner.steps(routine: routine, day: day, choices: choices)
    }

    public var current: SessionStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    public var isFinished: Bool { index >= steps.count }

    public var progress: Double {
        steps.isEmpty ? 1 : Double(min(index, steps.count)) / Double(steps.count)
    }

    /// Próxima serie después del paso actual.
    public var nextSet: SessionStep? {
        steps.dropFirst(index + 1).first { $0.isSet }
    }

    /// Ejercicio que se está haciendo o que viene después del descanso actual,
    /// si tiene alternativas.
    public var swappableExercise: Exercise? {
        guard let current else { return nil }
        let upcoming = current.isSet ? current : nextSet
        guard let blockID = upcoming?.blockID,
              let exercise = day.exercise(withID: blockID),
              let alternatives = exercise.alternatives, !alternatives.isEmpty
        else { return nil }
        return exercise
    }

    /// Alternativa elegida para un bloque (`nil` = ejercicio original).
    public func choice(for blockID: String) -> String? {
        choices[blockID]
    }

    public mutating func advance() {
        if index < steps.count { index += 1 }
    }

    public mutating func goBack() {
        if index > 0 { index -= 1 }
    }

    /// Cambia el ejercicio de un bloque y conserva la posición: si estabas en la
    /// serie 2 del original, quedas en la serie 2 de la alternativa.
    public mutating func choose(_ alternativeID: String?, for blockID: String) {
        let anchor = current
        choices[blockID] = alternativeID
        steps = SessionPlanner.steps(routine: routine, day: day, choices: choices)
        guard let anchor else {
            index = steps.count
            return
        }
        index = relocate(anchor) ?? min(index, steps.count)
    }

    private func relocate(_ anchor: SessionStep) -> Int? {
        let candidates = steps.indices.filter { steps[$0].blockID == anchor.blockID }
        guard let setNumber = anchor.setNumber else { return candidates.first }
        let lastSet = candidates.compactMap { steps[$0].setNumber }.max() ?? 1
        let target = min(setNumber, lastSet)
        let sameSet = candidates.filter {
            steps[$0].setNumber == target && steps[$0].isRest == anchor.isRest
        }
        return sameSet.first { steps[$0].side == anchor.side } ?? sameSet.first ?? candidates.first
    }
}

/// Convierte los bloques de un día en la lista plana de pasos.
enum SessionPlanner {
    static func steps(routine: Routine, day: Day, choices: [String: String]) -> [SessionStep] {
        var steps: [SessionStep] = []

        func append(_ blockID: String, _ title: String, _ kind: SessionStep.Kind,
                    details: [String] = [], equipment: [String] = []) {
            steps.append(SessionStep(id: steps.count, blockID: blockID, title: title, kind: kind,
                                     details: details, equipment: equipment))
        }

        for block in day.blocks {
            switch block {
            case .cardio(let cardio):
                let details = [cardio.intensity].compactMap { $0 } + (cardio.cues ?? [])
                append(cardio.id, cardio.name, .cardio(cardio.activity, duration: cardio.durationSeconds),
                       details: details)

            case .exercise(let original):
                let exercise = ResolvedExercise(original: original, choiceID: choices[original.id],
                                                defaults: routine.defaults)
                for set in 1...exercise.sets {
                    let sides: [SessionStep.Side?] = exercise.perSide ? [.first, .second] : [nil]
                    for side in sides {
                        append(original.id, exercise.name,
                               .set(exercise.target, number: set, of: exercise.sets, side: side),
                               details: exercise.details, equipment: exercise.equipment)
                    }
                    append(original.id, "Descanso", .rest(exercise.rest, afterSet: set))
                }
            }
        }

        if steps.last?.isRest == true {
            steps.removeLast()
        }
        return steps
    }
}

/// Ejercicio con valores efectivos: alternativa > ejercicio original > valores por defecto.
struct ResolvedExercise {
    let name: String
    let sets: Int
    let target: Target
    let rest: ValueRange
    let perSide: Bool
    let details: [String]
    let equipment: [String]

    init(original: Exercise, choiceID: String?, defaults: Defaults) {
        let chosen = original.alternatives?.first { $0.id == choiceID } ?? original
        name = chosen.name
        sets = Swift.max(1, chosen.sets ?? original.sets ?? defaults.sets)
        target = chosen.target ?? original.target ?? defaults.target
        rest = chosen.restSeconds ?? original.restSeconds ?? defaults.restSeconds
        perSide = chosen.perSide ?? false
        equipment = chosen.equipment ?? []

        var details: [String] = []
        if let load = chosen.load { details.append("Carga \(load)") }
        if let eccentric = chosen.tempo?.eccentricSeconds { details.append("Bajada en \(eccentric) s") }
        if let concentric = chosen.tempo?.concentricSeconds { details.append("Subida en \(concentric) s") }
        self.details = details + (chosen.cues ?? [])
    }
}
