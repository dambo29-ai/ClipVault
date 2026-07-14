//
//  ClipboardTimestampFormatterTests.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
//

import XCTest
@testable import ClipVault

final class ClipboardTimestampFormatterTests: XCTestCase {
    func testTodayDisplaysTimeOnly() {
        let now = date(
            2026,
            7,
            13,
            hour: 16,
            minute: 30
        )

        let clipDate = date(
            2026,
            7,
            13,
            hour: 10,
            minute: 42
        )

        let result = formattedTimestamp(
            for: clipDate,
            relativeTo: now
        )

        XCTAssertEqual(
            result,
            "10:42 AM"
        )
    }

    func testYesterdayDisplaysYesterdayAndTime() {
        let now = date(
            2026,
            7,
            13,
            hour: 16,
            minute: 30
        )

        let clipDate = date(
            2026,
            7,
            12,
            hour: 16,
            minute: 18
        )

        let result = formattedTimestamp(
            for: clipDate,
            relativeTo: now
        )

        XCTAssertEqual(
            result,
            "Yesterday, 4:18 PM"
        )
    }

    func testEarlierThisYearDisplaysMonthDayAndTime() {
        let now = date(
            2026,
            7,
            13,
            hour: 16,
            minute: 30
        )

        let clipDate = date(
            2026,
            7,
            3,
            hour: 14,
            minute: 15
        )

        let result = formattedTimestamp(
            for: clipDate,
            relativeTo: now
        )

        XCTAssertEqual(
            result,
            "Jul 3, 2:15 PM"
        )
    }

    func testPreviousYearIncludesYear() {
        let now = date(
            2026,
            7,
            13,
            hour: 16,
            minute: 30
        )

        let clipDate = date(
            2020,
            1,
            1,
            hour: 12,
            minute: 0
        )

        let result = formattedTimestamp(
            for: clipDate,
            relativeTo: now
        )

        XCTAssertEqual(
            result,
            "Jan 1, 2020, 12:00 PM"
        )
    }

    func testEndOfYearYesterdayUsesCalendarDay() {
        let now = date(
            2026,
            1,
            1,
            hour: 8,
            minute: 0
        )

        let clipDate = date(
            2025,
            12,
            31,
            hour: 23,
            minute: 45
        )

        let result = formattedTimestamp(
            for: clipDate,
            relativeTo: now
        )

        XCTAssertEqual(
            result,
            "Yesterday, 11:45 PM"
        )
    }

    private func formattedTimestamp(
        for date: Date,
        relativeTo now: Date
    ) -> String {
        ClipboardTimestampFormatter.string(
            for: date,
            relativeTo: now,
            calendar: testCalendar,
            locale: Locale(
                identifier: "en_US_POSIX"
            ),
            timeZone: testTimeZone
        )
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(
            identifier: .gregorian
        )

        calendar.timeZone = testTimeZone
        return calendar
    }

    private var testTimeZone: TimeZone {
        TimeZone(
            secondsFromGMT: 0
        )!
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = testCalendar
        components.timeZone = testTimeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        return components.date!
    }
}

