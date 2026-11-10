import Foundation

protocol PassioFetching: Sendable {
    func stopsData() async throws -> Data
    func busesData() async throws -> Data
}

/// Thin client for passio3.com. No auth; the payload rides in a form-encoded `json` field.
struct PassioAPI: PassioFetching {
    static func url(query: String) -> URL {
        URL(string: "https://passio3.com/www/mapGetData.php?" + query)!
    }

    static func formBody(json: String) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = json.addingPercentEncoding(withAllowedCharacters: allowed) ?? json
        return Data("json=\(encoded)".utf8)
    }

    private func post(query: String, json: String) async throws -> Data {
        var req = URLRequest(url: Self.url(query: query))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.formBody(json: json)
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func stopsData() async throws -> Data {
        try await post(query: "getStops=2", json: #"{"s0":"1007","sA":1}"#)
    }

    func busesData() async throws -> Data {
        try await post(query: "getBuses=2", json: #"{"s0":"1007","sA":1}"#)
    }
}
