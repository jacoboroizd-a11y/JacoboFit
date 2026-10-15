import XCTest
@testable import NutritionCore

final class CalendarGridTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }
    func testMonthGridIncludesLeapDayAndStartsOnMonday() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 14)))
        let grid = CalendarGrid.month(containing: date, calendar: calendar)
        XCTAssertEqual(grid.count, 42)
        XCTAssertEqual(calendar.component(.weekday, from: grid[0]), 2)
        XCTAssertTrue(grid.contains { calendar.component(.month, from: $0) == 2 && calendar.component(.day, from: $0) == 29 })
        XCTAssertEqual(Set(grid).count, 42)
    }
    func testCivilDaysStayAtMidnightAcrossDaylightSaving() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let grid = CalendarGrid.month(containing: date, calendar: calendar)
        for day in grid { XCTAssertEqual(calendar.component(.hour, from: day), 0) }
        for (a, b) in zip(grid, grid.dropFirst()) { XCTAssertEqual(calendar.dateComponents([.day], from: a, to: b).day, 1) }
    }
    func testWeekOfSundayCrossesYearWithoutDroppingDays() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2023, month: 1, day: 1)))
        let grid = CalendarGrid.week(containing: date, calendar: calendar)
        XCTAssertEqual(grid.count, 7)
        XCTAssertEqual(calendar.component(.year, from: grid[0]), 2022)
        XCTAssertEqual(calendar.component(.weekday, from: grid[0]), 2)
        XCTAssertEqual(calendar.component(.day, from: grid[6]), 1)
    }
}
