import Foundation

actor ScheduleService {
    static let shared = ScheduleService()

    /// How long fetched events are reused before hitting the network again.
    static let defaultMaxAge: TimeInterval = 15 * 60

    enum FetchError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case httpStatus(Int)
        case noData
        case parsingError

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL provided is invalid."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpStatus(let code) where code == 404 || code == 410:
                return "Calendar not found (HTTP \(code)). The link may have expired — copy a fresh iCal link from TimeEdit."
            case .httpStatus(let code) where code == 401 || code == 403:
                return "Access denied (HTTP \(code)). The calendar must be public; private feeds aren't supported."
            case .httpStatus(let code):
                return "The server returned an error (HTTP \(code)). Try again later."
            case .noData:
                return "No data received from the server."
            case .parsingError:
                return "The URL returned a webpage instead of a calendar file. Please ensure you are using the 'Subscribe' or 'iCal' link, not the browser URL."
            }
        }
    }

    private struct CacheEntry {
        let events: [Event]
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<[Event], Error>] = [:]

    private let session: URLSession = {
        // Timeouts prevent hanging
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// Returns cached events when younger than `maxAge`; pass 0 to force a refresh.
    /// Concurrent callers for the same URL share one request.
    func fetchSchedule(from urlString: String, maxAge: TimeInterval = ScheduleService.defaultMaxAge) async throws -> [Event] {
        let url = try Self.normalizedURL(urlString)
        let key = url.absoluteString

        if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < maxAge {
            return entry.events
        }
        if let task = inFlight[key] {
            return try await task.value
        }

        let session = self.session
        let task = Task<[Event], Error> {
            let (data, response) = try await session.data(from: url)
            return try Self.decode(data: data, response: response)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let events = try await task.value
        cache[key] = CacheEntry(events: events, fetchedAt: Date())
        return events
    }

    func invalidate(_ urlString: String) {
        guard let url = try? Self.normalizedURL(urlString) else { return }
        cache[url.absoluteString] = nil
    }

    // MARK: - Helpers

    static func normalizedURL(_ urlString: String) throws -> URL {
        var processed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if processed.lowercased().hasPrefix("webcal://") {
            processed = "https://" + processed.dropFirst(9)
        }
        guard let url = URL(string: processed), url.scheme != nil, url.host != nil else {
            throw FetchError.invalidURL
        }
        return url
    }

    static func decode(data: Data, response: URLResponse?) throws -> [Event] {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw FetchError.httpStatus(http.statusCode)
        }
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              !content.isEmpty else {
            throw FetchError.noData
        }
        // Common mistake: copying the web URL instead of the iCal URL
        let head = content.prefix(512).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if head.hasPrefix("<!doctype html") || head.hasPrefix("<html") {
            throw FetchError.parsingError
        }
        return ICalParser.parse(icsContent: content)
    }
}
