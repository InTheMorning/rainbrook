import XCTest
@testable import CitizenRadioCore

/// musicindex ADR 0083 R-VERSION-2 and R-VERSION-8 item 3: the version line form.
/// The expected lines copy the form of `BuildInfo::version_line` of the Rust crate `musicindex-build-info`.
final class BuildValuesTests: XCTestCase {
    func testTheLineHasTheVersionTheRevisionAndTheDate() {
        let values = BuildValues(
            name: "CitizenRadio", version: "0.1.0", gitRevision: "a1b2c3d", builtAt: "2026-11-25T18:00:00Z"
        )
        XCTAssertEqual(values.versionLine, "CitizenRadio 0.1.0 (a1b2c3d, 2026-11-25)")
    }

    func testADirtyRevisionStaysInTheLine() {
        let values = BuildValues(
            name: "CitizenRadio", version: "0.1.0", gitRevision: "a1b2c3d-dirty", builtAt: "2026-11-25T18:00:00Z"
        )
        XCTAssertEqual(values.versionLine, "CitizenRadio 0.1.0 (a1b2c3d-dirty, 2026-11-25)")
    }

    func testOnlyTheKnownValuesAreInTheParentheses() {
        XCTAssertEqual(
            BuildValues(name: "CitizenRadio", version: "0.1.0", gitRevision: "a1b2c3d", builtAt: nil).versionLine,
            "CitizenRadio 0.1.0 (a1b2c3d)"
        )
        XCTAssertEqual(
            BuildValues(name: "CitizenRadio", version: "0.1.0", gitRevision: "", builtAt: "2026-11-25T18:00:00Z")
                .versionLine,
            "CitizenRadio 0.1.0 (2026-11-25)"
        )
    }

    func testNoKnownValueGivesNoParentheses() {
        XCTAssertEqual(
            BuildValues(name: "CitizenRadio", version: "0.1.0", gitRevision: nil, builtAt: " ").versionLine,
            "CitizenRadio 0.1.0"
        )
    }
}
