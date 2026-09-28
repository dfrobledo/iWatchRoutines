import SwiftUI

@main
struct iWatchRoutinesApp: App {
    @StateObject private var store = RoutineStore()
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DayListView()
            }
            .environmentObject(store)
            .environmentObject(workout)
        }
    }
}

enum AppConfig {
    /// URL del JSON de la rutina, definida en `project.yml` (clave `RoutineURL` del Info.plist).
    static var routineURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "RoutineURL") as? String).flatMap(URL.init(string:))
    }
}

enum Clock {
    static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
