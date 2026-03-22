import Testing
import Foundation
@testable import TheTrimmerCore

@Suite("TimeParser Tests")
struct TimeParserTests {

    @Test("plain seconds")
    func plainSeconds() throws {
        #expect(try TimeParser.parse("90") == 90.0)
        #expect(try TimeParser.parse("0") == 0.0)
    }

    @Test("decimal seconds")
    func decimalSeconds() throws {
        #expect(try TimeParser.parse("90.5") == 90.5)
        #expect(try TimeParser.parse("0.001") == 0.001)
    }

    @Test("M:SS format")
    func minutesSeconds() throws {
        #expect(try TimeParser.parse("1:30") == 90.0)
        #expect(try TimeParser.parse("0:45") == 45.0)
        #expect(try TimeParser.parse("2:00") == 120.0)
    }

    @Test("H:MM:SS format")
    func hoursMinutesSeconds() throws {
        #expect(try TimeParser.parse("1:30:00") == 5400.0)
        #expect(try TimeParser.parse("0:01:30") == 90.0)
        #expect(try TimeParser.parse("2:00:00") == 7200.0)
    }

    @Test("M:SS.mmm with decimal seconds")
    func decimalInComponents() throws {
        #expect(try TimeParser.parse("1:30.5") == 90.5)
    }

    @Test("whitespace is trimmed")
    func whitespace() throws {
        #expect(try TimeParser.parse("  90  ") == 90.0)
    }

    @Test("empty string throws")
    func emptyString() {
        #expect(throws: TrimError.self) { try TimeParser.parse("") }
    }

    @Test("invalid string throws")
    func invalidString() {
        #expect(throws: TrimError.self) { try TimeParser.parse("abc") }
    }

    @Test("negative value throws")
    func negativeValue() {
        #expect(throws: TrimError.self) { try TimeParser.parse("-5") }
    }

    @Test("format outputs readable string")
    func formatOutput() {
        #expect(TimeParser.format(90.0) == "1:30.000")
        #expect(TimeParser.format(5400.0) == "1:30:00.000")
        #expect(TimeParser.format(0.0) == "0:00.000")
    }
}
