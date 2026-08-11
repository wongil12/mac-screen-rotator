import ScreenRotationCore
import Testing

@Suite("Rotation command generation")
struct RotationCommandBuilderTests {
    private let landscape = DisplaySnapshot(
        contextualID: 1,
        builtIn: true,
        main: true,
        rotation: .standard,
        logicalWidth: 1512,
        logicalHeight: 982,
        pixelWidth: 3024,
        pixelHeight: 1964,
        refreshRate: 120,
        scaled: true
    )

    @Test("Quarter turn swaps logical dimensions")
    func quarterTurn() {
        let command = RotationCommandBuilder().command(
            executable: "/opt/homebrew/bin/displayplacer",
            snapshot: landscape,
            target: .clockwise90
        )
        #expect(command.argument == "id:1 res:982x1512 hz:120 scaling:on degree:90")
    }

    @Test("Half turn preserves logical dimensions")
    func halfTurn() {
        let command = RotationCommandBuilder().command(
            executable: "/opt/homebrew/bin/displayplacer",
            snapshot: landscape,
            target: .upsideDown
        )
        #expect(command.argument == "id:1 res:1512x982 hz:120 scaling:on degree:180")
    }

    @Test("Returning from portrait swaps dimensions")
    func portraitToStandard() {
        let portrait = DisplaySnapshot(
            contextualID: 1,
            builtIn: true,
            main: true,
            rotation: .clockwise90,
            logicalWidth: 982,
            logicalHeight: 1512,
            pixelWidth: 1964,
            pixelHeight: 3024,
            refreshRate: 120,
            scaled: true
        )
        let command = RotationCommandBuilder().command(
            executable: "displayplacer",
            snapshot: portrait,
            target: .standard
        )
        #expect(command.argument == "id:1 res:1512x982 hz:120 scaling:on degree:0")
    }
}
