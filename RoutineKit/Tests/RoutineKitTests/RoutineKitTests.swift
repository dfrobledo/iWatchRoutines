import XCTest
@testable import RoutineKit

final class RoutineKitTests: XCTestCase {
    private func loadExample() throws -> Routine {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RoutineKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // RoutineKit
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("examples/plan-adaptacion.json"))
        return try Routine.decode(from: data)
    }

    private func makeEngine(day index: Int) throws -> SessionEngine {
        let routine = try loadExample()
        return SessionEngine(routine: routine, day: routine.days[index])
    }

    private func advance(_ engine: inout SessionEngine, until predicate: (SessionStep) -> Bool) {
        while let step = engine.current, !predicate(step) {
            engine.advance()
        }
    }

    // MARK: - Decoding

    func testDecodesExample() throws {
        let routine = try loadExample()
        XCTAssertEqual(routine.days.map(\.id), ["day1", "day2", "day3"])
        XCTAssertEqual(routine.defaults.sets, 3)
        XCTAssertEqual(routine.defaults.target, .reps(ValueRange(min: 10, max: 12)))
        XCTAssertEqual(routine.days[0].exerciseCount, 4)

        guard case .exercise(let plank) = routine.days[2].blocks.last else {
            return XCTFail("El último bloque del día 3 debería ser la plancha")
        }
        XCTAssertEqual(plank.target, .time(seconds: nil))
        XCTAssertEqual(routine.reminders(.afterSession).count, 1)
    }

    func testRoundTripKeepsRoutineIntact() throws {
        let routine = try loadExample()
        let data = try JSONEncoder().encode(routine)
        XCTAssertEqual(try Routine.decode(from: data), routine)
    }

    func testRejectsUnsupportedSchemaVersion() {
        let json = #"{"schemaVersion":2,"name":"x","defaults":{"sets":1,"target":{"kind":"reps","reps":{"min":1,"max":1}},"restSeconds":{"min":1,"max":1}},"days":[]}"#
        XCTAssertThrowsError(try Routine.decode(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? RoutineError, .unsupportedSchemaVersion(2))
        }
    }

    // MARK: - Planning

    func testDay1HasWarmupTwelveSetsAndRestsBetween() throws {
        let engine = try makeEngine(day: 0)
        // 1 calentamiento + 4 ejercicios × 3 series + 11 descansos (sin descanso final).
        XCTAssertEqual(engine.steps.count, 24)
        XCTAssertEqual(engine.steps.filter(\.isSet).count, 12)
        XCTAssertEqual(engine.steps.first?.kind, .cardio(.indoorCycling, duration: ValueRange(min: 300, max: 480)))
        XCTAssertEqual(engine.steps[1].kind, .set(.reps(ValueRange(min: 10, max: 12)), number: 1, of: 3, side: nil))
        XCTAssertEqual(engine.steps[2].kind, .rest(ValueRange(min: 60, max: 90), afterSet: 1))
        XCTAssertEqual(engine.steps.last?.title, "Giro ruso con fitball")
        XCTAssertTrue(engine.steps.last?.isSet ?? false)
    }

    func testTempoAndLoadBecomeDetails() throws {
        let engine = try makeEngine(day: 0)
        let legExtension = try XCTUnwrap(engine.steps.first { $0.blockID == "leg-extension" })
        XCTAssertEqual(Array(legExtension.details.prefix(2)), ["Carga ligera a moderada", "Bajada en 3 s"])
    }

    func testPerSideExerciseRunsBothSidesBeforeResting() throws {
        let engine = try makeEngine(day: 2)
        let rowSteps = engine.steps.filter { $0.blockID == "single-arm-db-row" }
        let sides = rowSteps.filter(\.isSet).map(\.side)
        XCTAssertEqual(sides, [.first, .second, .first, .second, .first, .second])
        XCTAssertTrue(rowSteps[0].isSet && rowSteps[1].isSet && rowSteps[2].isRest)
    }

    func testTimeTargetWithoutSecondsIsOpenEnded() throws {
        let engine = try makeEngine(day: 2)
        let plank = try XCTUnwrap(engine.steps.last)
        XCTAssertTrue(plank.isTimed)
        XCTAssertNil(plank.timerRange)
    }

    // MARK: - Navigation

    func testAdvanceAndGoBackStayInBounds() throws {
        var engine = try makeEngine(day: 0)
        engine.goBack()
        XCTAssertEqual(engine.index, 0)
        for _ in 0..<100 { engine.advance() }
        XCTAssertTrue(engine.isFinished)
        XCTAssertNil(engine.current)
        XCTAssertEqual(engine.progress, 1)
    }

    func testSwapMidExerciseKeepsSetNumber() throws {
        var engine = try makeEngine(day: 1)
        advance(&engine) { $0.blockID == "seated-cable-row" && $0.setNumber == 2 && $0.isSet }
        XCTAssertEqual(engine.swappableExercise?.id, "seated-cable-row")

        engine.choose("bench-single-arm-db-row", for: "seated-cable-row")
        XCTAssertEqual(engine.current?.title, "Remo a una mano apoyado en banco")
        XCTAssertEqual(engine.current?.setNumber, 2)
        XCTAssertEqual(engine.current?.side, .first)
        XCTAssertEqual(engine.choice(for: "seated-cable-row"), "bench-single-arm-db-row")

        engine.choose(nil, for: "seated-cable-row")
        XCTAssertEqual(engine.current?.title, "Remo sentado en polea baja")
        XCTAssertEqual(engine.current?.setNumber, 2)
    }

    func testSwapDuringRestBeforeExerciseKeepsTheRest() throws {
        var engine = try makeEngine(day: 1)
        advance(&engine) { $0.isRest && $0.blockID == "machine-chest-press" && $0.setNumber == 3 }
        let restIndex = engine.index
        XCTAssertEqual(engine.swappableExercise?.id, "seated-cable-row")

        engine.choose("standing-cable-row", for: "seated-cable-row")
        XCTAssertEqual(engine.index, restIndex)
        XCTAssertTrue(engine.current?.isRest ?? false)
        XCTAssertEqual(engine.nextSet?.title, "Remo de pie en polea baja")
    }

    func testExercisesWithoutAlternativesAreNotSwappable() throws {
        var engine = try makeEngine(day: 1)
        advance(&engine) { $0.blockID == "lat-pulldown" }
        XCTAssertNil(engine.swappableExercise)
    }
}
