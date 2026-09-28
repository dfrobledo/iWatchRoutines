import SwiftUI
import RoutineKit

struct DayListView: View {
    @EnvironmentObject private var store: RoutineStore
    @State private var activeDay: Day?

    var body: some View {
        List {
            if let routine = store.routine {
                Section(routine.name) {
                    ForEach(routine.days) { day in
                        Button {
                            activeDay = day
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.name).font(.headline)
                                if let focus = day.focus {
                                    Text(focus).font(.caption).foregroundStyle(.secondary)
                                }
                                Text("\(day.exerciseCount) ejercicios")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let questions = routine.openQuestions, !questions.isEmpty {
                    Section("Por definir") {
                        ForEach(questions) { question in
                            Text(question.question).font(.caption2)
                        }
                    }
                }
            } else {
                Text("Todavía no hay una rutina cargada.")
            }

            Section {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label(store.status == .loading ? "Actualizando…" : "Actualizar",
                          systemImage: "arrow.clockwise")
                }
                .disabled(store.status == .loading)

                if case .failed(let message) = store.status {
                    Text(message).font(.caption2).foregroundStyle(.orange)
                }
                if let lastUpdated = store.lastUpdated {
                    Text("Actualizada: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Rutinas")
        .task { await store.refresh() }
        .fullScreenCover(item: $activeDay) { day in
            if let routine = store.routine {
                SessionView(routine: routine, day: day)
            }
        }
    }
}
