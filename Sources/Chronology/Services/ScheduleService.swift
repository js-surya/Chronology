import Foundation
import Combine

class ScheduleService {
    static let shared = ScheduleService()
    
    private init() {}
    
    enum FetchError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case noData
        case parsingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL provided is invalid."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noData:
                return "No data received from the server."
            case .parsingError:
                return "The URL returned a webpage instead of a calendar file. Please ensure you are using the 'Subscribe' or 'iCal' link, not the browser URL."
            }
        }
    }
    
    func fetchSchedule(from urlString: String) async throws -> [Event] {
        // Handle webcal scheme
        var processedUrlString = urlString
        if urlString.lowercased().hasPrefix("webcal://") {
            processedUrlString = "https://" + urlString.dropFirst(9)
        }
        
        guard let url = URL(string: processedUrlString) else {
            throw FetchError.invalidURL
        }
        
        // Configure URLSession with timeout to prevent hanging
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // 10 second timeout
        config.timeoutIntervalForResource = 30 // 30 second total timeout
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(from: url)
        
        // Check for valid HTTP response
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw FetchError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw FetchError.noData
        }
        
        // Check if content is HTML (common mistake: copying web URL instead of iCal URL)
        if content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<!doctype html") ||
           content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<html") {
            throw FetchError.parsingError
        }
        
        // Parse on a detached task to avoid blocking any actor
        return await Task.detached(priority: .userInitiated) {
            return self.parse(icsContent: content)
        }.value
    }
    
    private func parse(icsContent: String) -> [Event] {
        var events: [Event] = []
        let lines = icsContent.components(separatedBy: .newlines)
        
        var currentEvent: (title: String, location: String, start: Date?, end: Date?, desc: String?)?
        var currentDescription = ""
        var isReadingDescription = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        // Alternative date formatter without 'Z' (for local time)
        let localDateFormatter = DateFormatter()
        localDateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("BEGIN:VEVENT") {
                currentEvent = ("", "", nil, nil, nil)
                currentDescription = ""
                isReadingDescription = false
            } else if trimmedLine.hasPrefix("END:VEVENT") {
                if let event = currentEvent, let start = event.start, let end = event.end {
                    let finalDesc = currentDescription.isEmpty ? event.desc : currentDescription
                    events.append(Event(
                        title: event.title.replacingOccurrences(of: "\\n", with: "\n")
                            .replacingOccurrences(of: "\\,", with: ","),
                        location: event.location.replacingOccurrences(of: "\\n", with: "\n")
                            .replacingOccurrences(of: "\\,", with: ","),
                        startTime: start,
                        endTime: end,
                        description: finalDesc?.replacingOccurrences(of: "\\n", with: "\n")
                            .replacingOccurrences(of: "\\,", with: ",")
                    ))
                }
                currentEvent = nil
                currentDescription = ""
                isReadingDescription = false
            } else if currentEvent != nil {
                // Handle continuation lines (start with space or tab)
                if trimmedLine.starts(with: " ") || trimmedLine.starts(with: "\t") {
                    if isReadingDescription {
                        currentDescription += trimmedLine.trimmingCharacters(in: .whitespaces)
                    }
                    continue
                }
                
                isReadingDescription = false
                
                if trimmedLine.hasPrefix("SUMMARY:") {
                    currentEvent?.title = String(trimmedLine.dropFirst(8))
                } else if trimmedLine.hasPrefix("LOCATION:") {
                    currentEvent?.location = String(trimmedLine.dropFirst(9))
                } else if trimmedLine.hasPrefix("DTSTART") {
                    // Handle both DTSTART: and DTSTART;TZID=...
                    if let colonIndex = trimmedLine.firstIndex(of: ":") {
                        let dateString = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        if let date = dateFormatter.date(from: dateString) {
                            currentEvent?.start = date
                        } else if let date = localDateFormatter.date(from: dateString) {
                            currentEvent?.start = date
                        }
                    }
                } else if trimmedLine.hasPrefix("DTEND") {
                    if let colonIndex = trimmedLine.firstIndex(of: ":") {
                        let dateString = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        if let date = dateFormatter.date(from: dateString) {
                            currentEvent?.end = date
                        } else if let date = localDateFormatter.date(from: dateString) {
                            currentEvent?.end = date
                        }
                    }
                } else if trimmedLine.hasPrefix("DESCRIPTION:") {
                    currentDescription = String(trimmedLine.dropFirst(12))
                    isReadingDescription = true
                }
            }
        }
        
        return events
    }
}
