//
//  RouteViewModel.swift
//  TUITestApp
//
//  Created by Michael Bielodied on 01.04.2025.
//

import Foundation
import Combine

final class RouteViewModel: ObservableObject {
    @Published var allCities: [City] = []
    @Published var fromCity: City?
    @Published var toCity: City?
    @Published var route: Route?
    @Published var errorMessage: String?

    private var connections: [Connection] = []
    private var routeFinder: RouteFinder?

    private let service: ConnectionsFetching

    init(service: ConnectionsFetching = ConnectionsService()) {
        self.service = service
        fetchConnections()
    }

    func fetchConnections() {
        service.fetchConnections { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let connections):
                    self?.connections = connections
                    self?.routeFinder = RouteFinder(connections: connections)
                    self?.allCities = connections.allUniqueCities()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func findRoute() {
        guard let from = fromCity?.name, !from.isEmpty,
              let to = toCity?.name, !to.isEmpty else {
            errorMessage = "Please select both cities before finding a route."
            route = nil
            return
        }

        guard from != to else {
            errorMessage = "Departure and destination must be different."
            route = nil
            return
        }

        if let foundRoute = routeFinder?.findCheapestRoute(from: from, to: to) {
            self.route = foundRoute
            self.errorMessage = nil
        } else {
            self.route = nil
            self.errorMessage = "No route found between \(from) and \(to)."
        }
    }
}
