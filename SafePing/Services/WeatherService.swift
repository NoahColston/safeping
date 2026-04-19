// SafePing — WeatherService.swift
// Fetches current weather from the Open-Meteo REST API (no key required).
// Caches the last successful response in UserDefaults for offline display.
//
// Networking paradigm: async/await URLSession GET → Codable decode → publish on MainActor.
// Offline: falls back to cached JSON if the network request throws.

import Foundation
import Combine

// [OOP] ObservableObject encapsulates all weather state
@MainActor
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let cacheKey = "sp_weather_cache"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        loadCached()
    }

    // [Procedural] Sequential fetch → decode → cache → publish
    func fetchWeather(latitude: Double = 37.7749, longitude: Double = -122.4194) async {
        isLoading = true
        errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)"
            + "&longitude=\(longitude)"
            + "&current_weather=true"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid weather URL"
            isLoading = false
            return
        }

        do {
            // [Functional] map over bytes with Codable transform
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            currentWeather = WeatherSnapshot(from: response)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            errorMessage = "Could not load weather"
            // offline fallback already loaded by loadCached()
        }

        isLoading = false
    }

    // Load the last cached response so the UI shows stale data while offline
    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return }
        currentWeather = WeatherSnapshot(from: response)
    }
}

// MARK: - Codable models for Open-Meteo response

struct OpenMeteoResponse: Codable {
    let currentWeather: CurrentWeather

    enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
    }

    struct CurrentWeather: Codable {
        let temperature: Double
        let windspeed: Double
        let weathercode: Int
    }
}

// MARK: - Domain model

struct WeatherSnapshot {
    let temperatureCelsius: Double
    let windspeedKph: Double
    let condition: String
    let symbolName: String   // SF Symbol name

    init(from response: OpenMeteoResponse) {
        let cw = response.currentWeather
        temperatureCelsius = cw.temperature
        windspeedKph = cw.windspeed
        (condition, symbolName) = WeatherSnapshot.interpret(code: cw.weathercode)
    }

    var temperatureFahrenheit: Double { temperatureCelsius * 9 / 5 + 32 }

    // [Functional] pure function: WMO weather code → (description, SF Symbol)
    static func interpret(code: Int) -> (String, String) {
        switch code {
        case 0:        return ("Clear",         "sun.max.fill")
        case 1...3:    return ("Partly Cloudy", "cloud.sun.fill")
        case 45, 48:   return ("Foggy",         "cloud.fog.fill")
        case 51...67:  return ("Rain",          "cloud.rain.fill")
        case 71...77:  return ("Snow",          "snowflake")
        case 80...82:  return ("Showers",       "cloud.heavyrain.fill")
        case 95...99:  return ("Thunderstorm",  "cloud.bolt.rain.fill")
        default:       return ("Cloudy",        "cloud.fill")
        }
    }
}
