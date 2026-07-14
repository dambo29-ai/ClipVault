//
//  ClipboardTimestampFormatter.swift
//  ClipVault
//
//  Created by Alejandro Mora on 7/13/26.
////
//  ClipboardTimestampFormatter.swift
//  ClipVault
//

import Foundation

enum ClipboardTimestampFormatter {
    static func string(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var workingCalendar = calendar
        workingCalendar.timeZone = timeZone

        let timeString = formattedString(
            for: date,
            template: "j:mm",
            locale: locale,
            timeZone: timeZone
        )

        if workingCalendar.isDate(
            date,
            inSameDayAs: now
        ) {
            return timeString
        }

        if let yesterday = workingCalendar.date(
            byAdding: .day,
            value: -1,
            to: now
        ),
           workingCalendar.isDate(
               date,
               inSameDayAs: yesterday
           ) {
            return "Yesterday, \(timeString)"
        }

        let dateYear = workingCalendar.component(
            .year,
            from: date
        )

        let currentYear = workingCalendar.component(
            .year,
            from: now
        )

        let dateString: String

        if dateYear == currentYear {
            dateString = formattedString(
                for: date,
                template: "MMM d",
                locale: locale,
                timeZone: timeZone
            )
        } else {
            dateString = formattedString(
                for: date,
                template: "MMM d, yyyy",
                locale: locale,
                timeZone: timeZone
            )
        }

        return "\(dateString), \(timeString)"
    }

    private static func formattedString(
        for date: Date,
        template: String,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(
            template
        )

        return normalizedSpaces(
            in: formatter.string(from: date)
        )
    }

    private static func normalizedSpaces(
        in string: String
    ) -> String {
        string
            .replacingOccurrences(
                of: "\u{202F}",
                with: " "
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
    }
}
