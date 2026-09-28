import Foundation
import RoutineKit
import WatchKit

/// Estado de la sesión en pantalla: envuelve `SessionEngine` y da los avisos hápticos.
@MainActor
final class SessionModel: ObservableObject {
    @Published private(set) var engine: SessionEngine
    @Published private(set) var stepStartedAt = Date()

    private var reachedMin = false
    private var reachedMax = false
    private var ticker: Timer?

    init(routine: Routine, day: Day) {
        engine = SessionEngine(routine: routine, day: day)
    }

    var beforeSessionReminders: [String] { engine.routine.reminders(.beforeSession) }
    var afterSessionReminders: [String] { engine.routine.reminders(.afterSession) }

    /// En los descansos se va rotando un recordatorio de "durante la sesión".
    var restReminder: String? {
        let reminders = engine.routine.reminders(.duringSession)
        guard engine.current?.isRest == true, !reminders.isEmpty else { return nil }
        return reminders[engine.index % reminders.count]
    }

    func start() {
        guard ticker == nil else { return }
        stepStartedAt = Date()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    func advance() {
        engine.advance()
        stepChanged()
        play(engine.isFinished ? .success : .click)
    }

    func goBack() {
        engine.goBack()
        stepChanged()
    }

    func choose(_ alternativeID: String?, for blockID: String) {
        let before = engine.current
        engine.choose(alternativeID, for: blockID)
        // Cambiar el ejercicio que viene no reinicia el descanso en curso.
        if engine.current != before {
            stepChanged()
        }
    }

    private func stepChanged() {
        stepStartedAt = Date()
        reachedMin = false
        reachedMax = false
    }

    /// Rango 60–90 s: al llegar al mínimo avisa suave ("ya puedes"), al máximo avisa fuerte.
    private func tick() {
        guard let range = engine.current?.timerRange else { return }
        let elapsed = Int(Date().timeIntervalSince(stepStartedAt))
        if !reachedMin, elapsed >= range.min {
            reachedMin = true
            if range.isFixed {
                reachedMax = true
                play(.notification)
            } else {
                play(.directionUp)
            }
        }
        if !reachedMax, elapsed >= range.max {
            reachedMax = true
            play(.notification)
        }
    }

    private func play(_ haptic: WKHapticType) {
        WKInterfaceDevice.current().play(haptic)
    }
}
