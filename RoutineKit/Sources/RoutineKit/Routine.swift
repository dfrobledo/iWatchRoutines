import Foundation

/// Rutina completa, tal como la describe `schema/routine.schema.json`.
public struct Routine: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let name: String
    public let defaults: Defaults
    public let schedule: Schedule?
    public let days: [Day]
    public let progression: Progression?
    public let safetyReminders: [SafetyReminder]?
    public let openQuestions: [OpenQuestion]?

    public static let supportedSchemaVersion = 1

    public static func decode(from data: Data) throws -> Routine {
        let routine = try JSONDecoder().decode(Routine.self, from: data)
        guard routine.schemaVersion == supportedSchemaVersion else {
            throw RoutineError.unsupportedSchemaVersion(routine.schemaVersion)
        }
        return routine
    }

    public func reminders(_ moment: SafetyReminder.Moment) -> [String] {
        (safetyReminders ?? []).filter { $0.when == moment }.map(\.text)
    }
}

public enum RoutineError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

/// Rango de enteros; un valor fijo es `min == max`.
public struct ValueRange: Codable, Hashable, Sendable {
    public let min: Int
    public let max: Int

    public var isFixed: Bool { min == max }
}

public enum Target: Hashable, Sendable {
    case reps(ValueRange)
    /// `nil` cuando la rutina no especifica la duración: se usa un cronómetro abierto.
    case time(seconds: ValueRange?)
}

extension Target: Codable {
    private enum CodingKeys: String, CodingKey { case kind, reps, seconds }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "reps":
            self = .reps(try container.decode(ValueRange.self, forKey: .reps))
        case "time":
            self = .time(seconds: try container.decodeIfPresent(ValueRange.self, forKey: .seconds))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "Tipo de objetivo desconocido: \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .reps(let reps):
            try container.encode("reps", forKey: .kind)
            try container.encode(reps, forKey: .reps)
        case .time(let seconds):
            try container.encode("time", forKey: .kind)
            try container.encode(seconds, forKey: .seconds)
        }
    }
}

public struct Defaults: Codable, Equatable, Sendable {
    public let sets: Int
    public let target: Target
    public let restSeconds: ValueRange
}

public struct Schedule: Codable, Equatable, Sendable {
    public let sessionsPerWeek: Int?
    public let suggestedWeekdays: [String]?
}

public struct Day: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let focus: String?
    public let blocks: [Block]

    public var exerciseCount: Int {
        blocks.filter {
            if case .exercise = $0 { return true }
            return false
        }.count
    }

    public func exercise(withID id: String) -> Exercise? {
        for case .exercise(let exercise) in blocks where exercise.id == id {
            return exercise
        }
        return nil
    }
}

public enum Block: Equatable, Sendable {
    case cardio(CardioBlock)
    case exercise(Exercise)

    public var id: String {
        switch self {
        case .cardio(let block): return block.id
        case .exercise(let exercise): return exercise.id
        }
    }
}

extension Block: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "cardio":
            self = .cardio(try CardioBlock(from: decoder))
        case "exercise":
            self = .exercise(try Exercise(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Tipo de bloque desconocido: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .cardio(let block):
            try container.encode("cardio", forKey: .type)
            try block.encode(to: encoder)
        case .exercise(let exercise):
            try container.encode("exercise", forKey: .type)
            try exercise.encode(to: encoder)
        }
    }
}

public enum CardioActivity: String, Codable, Sendable {
    case indoorCycling, elliptical, treadmillWalk
}

public struct CardioBlock: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let role: String?
    public let activity: CardioActivity
    public let durationSeconds: ValueRange
    public let intensity: String?
    public let cues: [String]?
}

/// Ejercicio de fuerza. Las alternativas usan el mismo tipo (sin `alternatives` propias).
public struct Exercise: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let equipment: [String]?
    public let sets: Int?
    public let target: Target?
    public let restSeconds: ValueRange?
    public let perSide: Bool?
    public let tempo: Tempo?
    public let load: String?
    public let cues: [String]?
    /// Solo en alternativas: condición en la que se usa.
    public let when: String?
    public let alternatives: [Exercise]?
}

public struct Tempo: Codable, Equatable, Sendable {
    public let eccentricSeconds: Int?
    public let concentricSeconds: Int?
}

public struct Progression: Codable, Equatable, Sendable {
    public let phases: [Phase]?
    public let rule: ProgressionRule?
    public let reviewAfterWeeks: Int?

    public struct Phase: Codable, Equatable, Sendable {
        public let name: String
        public let fromWeek: Int
        public let toWeek: Int?
        public let keepExercises: Bool?
        public let notes: [String]?
    }

    public struct ProgressionRule: Codable, Equatable, Sendable {
        public let kind: String
        public let fromWeek: Int
        public let condition: String?
    }
}

public struct SafetyReminder: Codable, Equatable, Sendable {
    public enum Moment: String, Codable, Sendable {
        case beforeSession, duringSession, afterSession
    }

    public let when: Moment
    public let text: String
}

public struct OpenQuestion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let refersTo: String
    public let question: String
    public let suggestedAnswer: String?
}
