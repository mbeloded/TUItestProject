//
//  RouteFinder.swift
//  TUITestApp
//
//  Created by Michael Bielodied on 01.04.2025.
//

import Foundation

final class RouteFinder {
    private var graph: [String: [Connection]] = [:]

    init(connections: [Connection]) {
        buildGraph(from: connections)
    }

    private func buildGraph(from connections: [Connection]) {
        for connection in connections {
            graph[connection.from, default: []].append(connection)
        }
    }

    func findCheapestRoute(from start: String, to destination: String) -> Route? {
        var distances: [String: Int] = [:]
        var previous: [String: Connection] = [:]
        var visited: Set<String> = []

        var pq = PriorityQueue<(city: String, cost: Int)> { $0.cost < $1.cost }
        pq.enqueue((city: start, cost: 0))
        distances[start] = 0

        while let (currentCity, currentCost) = pq.dequeue() {
            if visited.contains(currentCity) { continue }
            visited.insert(currentCity)

            if currentCity == destination {
                break
            }

            for connection in graph[currentCity] ?? [] {
                let neighbor = connection.to
                let newCost = currentCost + connection.price

                if distances[neighbor, default: Int.max] > newCost {
                    distances[neighbor] = newCost
                    previous[neighbor] = connection
                    pq.enqueue((city: neighbor, cost: newCost))
                }
            }
        }

        // Reconstruct path
        var path: [Connection] = []
        var currentCity = destination

        while let connection = previous[currentCity] {
            path.insert(connection, at: 0)
            currentCity = connection.from
        }

        guard !path.isEmpty, path.first?.from == start else {
            return nil // No route found
        }

        return Route(connections: path)
    }
}
