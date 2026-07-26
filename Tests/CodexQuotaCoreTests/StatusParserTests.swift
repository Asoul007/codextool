import XCTest
@testable import CodexQuotaCore

final class StatusParserTests: XCTestCase {
    func testParsesChineseStatusImport() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = """
        Codex 用量
        5小时剩余 68%
        一周剩余 42%
        重置机会 3次
        """

        let snapshot = try StatusParser().parse(text, now: now)

        XCTAssertEqual(snapshot.fiveHourRemainingPercent, 68)
        XCTAssertEqual(snapshot.weeklyRemainingPercent, 42)
        XCTAssertEqual(snapshot.resetOpportunities, 3)
        XCTAssertEqual(snapshot.source, .cliStatusImport)
        XCTAssertEqual(snapshot.capturedAt, now)
    }

    func testParsesEnglishStatusImport() throws {
        let text = """
        5-hour remaining: 71%
        weekly remaining: 39%
        reset opportunities: 2
        """

        let snapshot = try StatusParser().parse(text)

        XCTAssertEqual(snapshot.fiveHourRemainingPercent, 71)
        XCTAssertEqual(snapshot.weeklyRemainingPercent, 39)
        XCTAssertEqual(snapshot.resetOpportunities, 2)
    }

    func testParsesChatGPTAccountUsageMenuText() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 18
        let now = Calendar.current.date(from: components)!

        let snapshot = try StatusParser().parse("剩余用量\n1 周 69% 7月25日", now: now)

        XCTAssertEqual(snapshot.weeklyRemainingPercent, 69)
        XCTAssertEqual(snapshot.weeklyRemainingText, "69% · 7月25日重置")
        XCTAssertEqual(Calendar.current.component(.month, from: snapshot.weeklyResetAt!), 7)
        XCTAssertEqual(Calendar.current.component(.day, from: snapshot.weeklyResetAt!), 25)
        XCTAssertNil(snapshot.fiveHourRemainingPercent)
        XCTAssertNil(snapshot.resetOpportunities)
    }

    func testRejectsTextWithoutQuotaFields() {
        XCTAssertThrowsError(try StatusParser().parse("logged in with ChatGPT")) { error in
            XCTAssertEqual(error as? StatusParserError, .noQuotaFieldsFound)
        }
    }
}
