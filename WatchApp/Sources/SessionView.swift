import SwiftUI
import RoutineKit

struct SessionView: View {
    @StateObject private var model: SessionModel
    @EnvironmentObject private var workout: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingMenu = false
    @State private var showingSwap = false

    init(routine: Routine, day: Day) {
        _model = StateObject(wrappedValue: SessionModel(routine: routine, day: day))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let step = model.engine.current {
                    StepView(step: step, model: model, heartRate: workout.heartRate) {
                        showingSwap = true
                    }
                } else {
                    FinishedView(reminders: model.afterSessionReminders) {
                        finish(save: true)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            model.start()
            await workout.requestAuthorization()
            await workout.start()
        }
        .confirmationDialog("Sesión", isPresented: $showingMenu) {
            if model.engine.index > 0 {
                Button("Paso anterior") { model.goBack() }
            }
            Button("Terminar y guardar") { finish(save: true) }
            Button("Descartar sesión", role: .destructive) { finish(save: false) }
        }
        .sheet(isPresented: $showingSwap) {
            SwapView(model: model)
        }
    }

    private func finish(save: Bool) {
        model.stop()
        Task {
            await workout.end(save: save)
            dismiss()
        }
    }
}

struct StepView: View {
    let step: SessionStep
    @ObservedObject var model: SessionModel
    let heartRate: Double?
    let onSwap: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                header
                content

                Button(action: model.advance) {
                    Text(primaryLabel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .doubleTapPrimaryAction()

                if model.engine.swappableExercise != nil {
                    Button(action: onSwap) {
                        Label("Cambiar ejercicio", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.footnote)
                }

                ForEach(step.details, id: \.self) { detail in
                    Text("• \(detail)").font(.caption2).foregroundStyle(.secondary)
                }
                if !step.equipment.isEmpty {
                    Text(step.equipment.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack {
                Text("\(model.engine.index + 1)/\(model.engine.steps.count)")
                Spacer()
                if let heartRate {
                    Label("\(Int(heartRate))", systemImage: "heart.fill").foregroundStyle(.red)
                }
            }
            .font(.caption2)
            ProgressView(value: model.engine.progress).tint(accent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step.kind {
        case .cardio(_, let duration):
            Text("Calentamiento").font(.caption).foregroundStyle(.secondary)
            Text(step.title).font(.headline)
            RangeTimerView(start: model.stepStartedAt, range: duration)

        case .set(let target, let number, let total, let side):
            Text(step.title).font(.headline).lineLimit(3)
            Text("Serie \(number) de \(total)\(sideLabel(side))")
                .font(.caption).foregroundStyle(.secondary)
            switch target {
            case .reps(let reps):
                Text(reps.isFixed ? "\(reps.min) reps" : "\(reps.min)–\(reps.max) reps")
                    .font(.title2.bold())
            case .time(let seconds):
                if let seconds {
                    RangeTimerView(start: model.stepStartedAt, range: seconds)
                } else {
                    StopwatchView(start: model.stepStartedAt)
                }
            }
            if step.id == model.engine.steps.first(where: \.isSet)?.id {
                ForEach(model.beforeSessionReminders, id: \.self) { reminder in
                    Text(reminder).font(.caption2).foregroundStyle(.yellow)
                }
            }

        case .rest(let range, _):
            Text("Descanso").font(.headline)
            RangeTimerView(start: model.stepStartedAt, range: range)
            if let next = model.engine.nextSet {
                Text("Sigue: \(next.title)").font(.caption)
                if case .set(_, let number, let total, let side) = next.kind {
                    Text("Serie \(number) de \(total)\(sideLabel(side))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let reminder = model.restReminder {
                Text(reminder).font(.caption2).foregroundStyle(.yellow)
            }
        }
    }

    private var primaryLabel: String {
        switch step.kind {
        case .cardio: return "Terminar calentamiento"
        case .set: return "Hecho"
        case .rest: return "Siguiente"
        }
    }

    private var accent: Color {
        switch step.kind {
        case .cardio: return .orange
        case .set: return .green
        case .rest: return .blue
        }
    }

    private func sideLabel(_ side: SessionStep.Side?) -> String {
        switch side {
        case .first: return " · primer lado"
        case .second: return " · segundo lado"
        case nil: return ""
        }
    }
}

/// Cuenta atrás hasta el máximo del rango; después del mínimo indica que ya se puede seguir.
struct RangeTimerView: View {
    let start: Date
    let range: ValueRange

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(start)))
            VStack(alignment: .leading, spacing: 0) {
                if elapsed < range.max {
                    Text(Clock.format(range.max - elapsed))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(elapsed >= range.min ? "Ya puedes seguir" : "Mínimo \(Clock.format(range.min))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("+\(Clock.format(elapsed - range.max))")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                    Text("¡Tiempo!").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Cronómetro abierto para ejercicios por tiempo sin duración definida.
struct StopwatchView: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            Text(Clock.format(max(0, Int(context.date.timeIntervalSince(start)))))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}

struct SwapView: View {
    @ObservedObject var model: SessionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let exercise = model.engine.swappableExercise {
            List {
                option(nil, name: exercise.name, subtitle: "Original", blockID: exercise.id)
                ForEach(exercise.alternatives ?? []) { alternative in
                    option(alternative.id, name: alternative.name,
                           subtitle: alternative.when ?? alternative.equipment?.joined(separator: ", "),
                           blockID: exercise.id)
                }
            }
            .navigationTitle("Cambiar por")
        } else {
            Text("Este ejercicio no tiene alternativas.")
        }
    }

    private func option(_ id: String?, name: String, subtitle: String?, blockID: String) -> some View {
        Button {
            model.choose(id, for: blockID)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                    if let subtitle {
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if model.engine.choice(for: blockID) == id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

struct FinishedView: View {
    let reminders: [String]
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle).foregroundStyle(.green)
                Text("¡Sesión completa!").font(.headline)
                ForEach(reminders, id: \.self) { reminder in
                    Text(reminder).font(.caption).foregroundStyle(.yellow).multilineTextAlignment(.center)
                }
                Button("Guardar y salir", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .doubleTapPrimaryAction()
            }
        }
    }
}

extension View {
    /// Double Tap (juntar índice y pulgar) pulsa el botón principal. Requiere watchOS 11.
    @ViewBuilder
    func doubleTapPrimaryAction() -> some View {
        if #available(watchOS 11.0, *) {
            handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}
