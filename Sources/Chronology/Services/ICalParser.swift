import Foundation

/// Minimal RFC 5545 VEVENT parser. Handles line folding, TZID, all-day dates and text escapes.
/// Recurrence rules are not expanded (TimeEdit feeds already list every occurrence).
enum ICalParser {
    static func parse(icsContent: String) -> [Event] {
        var events: [Event] = []
        var current: [String: (params: [String: String], value: String)]?

        for line in unfold(icsContent) {
            if line == "BEGIN:VEVENT" {
                current = [:]
            } else if line == "END:VEVENT" {
                if let props = current, let event = makeEvent(from: props) {
                    events.append(event)
                }
                current = nil
            } else if current != nil, let (name, params, value) = splitProperty(line) {
                // Keep the first occurrence of each property
                if current?[name] == nil {
                    current?[name] = (params, value)
                }
            }
        }
        return events
    }

    // MARK: - Lines

    /// Joins folded lines (CRLF followed by a space or tab) back into logical lines.
    static func unfold(_ content: String) -> [String] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if let first = raw.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += raw.dropFirst()
            } else {
                lines.append(String(raw))
            }
        }
        return lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Splits `NAME;PARAM=VAL:value` into its parts. Quoted parameter values may contain ':' or ';'.
    static func splitProperty(_ line: String) -> (String, [String: String], String)? {
        var inQuotes = false
        var colon: String.Index?
        for idx in line.indices {
            let ch = line[idx]
            if ch == "\"" { inQuotes.toggle() }
            else if ch == ":" && !inQuotes { colon = idx; break }
        }
        guard let colon else { return nil }

        let head = line[..<colon]
        let value = String(line[line.index(after: colon)...])
        var parts = head.split(separator: ";").map(String.init)
        guard !parts.isEmpty else { return nil }
        let name = parts.removeFirst().uppercased()

        var params: [String: String] = [:]
        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            params[kv[0].uppercased()] = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return (name, params, value)
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        while let ch = iterator.next() {
            guard ch == "\\", let next = iterator.next() else {
                result.append(ch)
                continue
            }
            switch next {
            case "n", "N": result.append("\n")
            default: result.append(next) // \, \; \\
            }
        }
        return result
    }

    // MARK: - Dates

    static func parseDate(_ value: String, params: [String: String]) -> (date: Date, isAllDay: Bool)? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        if params["VALUE"]?.uppercased() == "DATE" || (value.count == 8 && !value.contains("T")) {
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = .current
            return formatter.date(from: value).map { ($0, true) }
        }

        if value.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            // Floating time when TZID is absent or unknown
            formatter.timeZone = params["TZID"].flatMap(TimeZone.init(identifier:)) ?? .current
        }
        return formatter.date(from: value).map { ($0, false) }
    }

    // MARK: - Event

    private static func makeEvent(from props: [String: (params: [String: String], value: String)]) -> Event? {
        guard let startProp = props["DTSTART"],
              let (start, isAllDay) = parseDate(startProp.value, params: startProp.params) else { return nil }

        let end: Date
        if let endProp = props["DTEND"], let parsed = parseDate(endProp.value, params: endProp.params) {
            end = parsed.date
        } else if isAllDay {
            end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        } else {
            end = start
        }

        let title = props["SUMMARY"].map { unescape($0.value) } ?? ""
        let location = props["LOCATION"].map { unescape($0.value) } ?? ""
        let description = props["DESCRIPTION"].map { unescape($0.value) }
        // Stable identity across refreshes; fall back to content when UID is missing
        // (start is appended so recurring instances sharing a UID stay unique)
        let uid = props["UID"]?.value ?? title
        let id = "\(uid)@\(Int(start.timeIntervalSince1970))"

        return Event(
            id: id,
            title: title,
            location: location,
            startTime: start,
            endTime: max(end, start),
            description: description,
            isAllDay: isAllDay
        )
    }
}
