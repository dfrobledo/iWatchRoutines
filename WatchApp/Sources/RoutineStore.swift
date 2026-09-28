import Foundation
import RoutineKit

/// Descarga la rutina desde la nube y guarda la última copia válida para usarla sin conexión.
@MainActor
final class RoutineStore: ObservableObject {
    enum Status: Equatable {
        case idle, loading
        case failed(String)
    }

    @Published private(set) var routine: Routine?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var status: Status = .idle

    private let cacheURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("routine.json")

    init() {
        loadCached()
    }

    func refresh() async {
        guard let url = AppConfig.routineURL, status != .loading else { return }
        status = .loading
        do {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let routine = try Routine.decode(from: data)
            try data.write(to: cacheURL, options: .atomic)
            self.routine = routine
            lastUpdated = Date()
            status = .idle
        } catch {
            status = .failed(routine == nil
                ? "No se pudo descargar la rutina."
                : "Sin conexión: usando la última copia.")
        }
    }

    /// Primero la copia descargada; si no existe, la que viene incluida en la app.
    private func loadCached() {
        if let data = try? Data(contentsOf: cacheURL), let routine = try? Routine.decode(from: data) {
            self.routine = routine
            lastUpdated = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path))?[.modificationDate] as? Date
        } else if let url = Bundle.main.url(forResource: "actual", withExtension: "json"),
                  let data = try? Data(contentsOf: url) {
            routine = try? Routine.decode(from: data)
        }
    }
}
