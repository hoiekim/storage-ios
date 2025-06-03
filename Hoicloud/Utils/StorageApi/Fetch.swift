//
//  HttpUtil.swift
//  Hoicloud
//
//  Created by Hoie Kim on 5/14/25.
//

import SwiftUI

func appendApiKey(
    to urlString: String,
    with apiKey: String
) -> String {
    return urlString + "?api_key=" + apiKey
}

func constructApiUrl(
    apiHost: String,
    apiKey: String,
    route: String = "",
    parameter: String? = nil
) -> String {
    var routeUrlString = apiHost + "/" + route
    let encodedParam = parameter?.addingPercentEncoding(
        withAllowedCharacters: .urlHostAllowed
    )
    if encodedParam != nil {
        routeUrlString = routeUrlString + "/" + encodedParam!
    }
    return appendApiKey(to: routeUrlString, with: apiKey)
}

func getUrlRequest(
    apiHost: String,
    apiKey: String,
    route: String = "",
    parameter: String? = nil,
    method: String? = "GET"
) -> URLRequest? {
    if apiHost.isEmpty || apiKey.isEmpty { return nil }

    let fullUrlString = constructApiUrl(
        apiHost: apiHost,
        apiKey: apiKey,
        route: route,
        parameter: parameter
    )
    
    guard let url = URL(string: fullUrlString) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    
    return request
}

class Fetch {
    var apiHost: String
    var apiKey: String
    
    init(apiHost: String, apiKey: String) {
        self.apiHost = apiHost
        self.apiKey = apiKey
    }
    
    func data(
        method: String? = "GET",
        route: String = "",
        parameter: String? = nil,
        body: Codable? = nil,
    ) async -> (Int, Data)? {
        do {
            guard var request = getUrlRequest(
                apiHost: apiHost,
                apiKey: apiKey,
                route: route,
                parameter: parameter,
                method: method
            ) else { return nil }
            
            if body != nil {
                let httpBody = try JSONEncoder().encode(body!)
                request.httpBody = httpBody
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let response = response as? HTTPURLResponse {
                return (response.statusCode, data)
            } else {
                print("Unknown response: \(String(describing: response))")
            }
        } catch {
            if !Task.isCancelled {
                print(
                    "Failed Fetch.data: [\(method ?? "GET")]"
                    + " \(route)/\(parameter ?? "")"
                    + "\n\(error)"
                )
            }
        }
        
        return nil
    }

    @discardableResult
    func json<Response: Decodable>(
        _ type: Response.Type,
        method: String? = "GET",
        route: String = "",
        parameter: String? = nil,
        body: Codable? = nil
    ) async -> (Int, Response)? {
        guard let result = await data(
            method: method,
            route: route,
            parameter: parameter,
            body: body
        ) else { return nil }
        
        let (statusCode, data) = result
        
        do {
            guard !data.isEmpty else { return nil }
            let json = try JSONDecoder().decode(Response.self, from: data)
            return (statusCode, json)
        } catch {
            print(
                "Failed Fetch.json: [\(String(describing: method))]"
                + " \(route)/\(parameter ?? "")"
            )
            print(
                "due to a failure to decode data: \(data.debugDescription)"
                + "\n\(error)"
            )
        }
        
        return nil
    }
}
