//
//  RouteFinderTests.swift
//  TUITestProject
//
//  Created by Michael Bielodied on 01.04.2025.
//

import XCTest
@testable import TUITestProject

final class RouteFinderTests: XCTestCase {

    var connections: [Connection]!

    override func setUp() {
        super.setUp()
        connections = [
            Connection(from: "A", to: "B", coordinates: dummyCoords(), price: 100),
            Connection(from: "B", to: "C", coordinates: dummyCoords(), price: 100),
            Connection(from: "A", to: "C", coordinates: dummyCoords(), price: 300),
            Connection(from: "C", to: "D", coordinates: dummyCoords(), price: 50)
        ]
    }

    func testCheapestRouteFromAtoC() {
        let finder = RouteFinder(connections: connections)
        let route = finder.findCheapestRoute(from: "A", to: "C")
        XCTAssertEqual(route?.totalPrice, 200)
        XCTAssertEqual(route?.connections.map { $0.from }, ["A", "B"])
        XCTAssertEqual(route?.connections.map { $0.to }, ["B", "C"])
    }

    func testNoRouteFromDToA() {
        let finder = RouteFinder(connections: connections)
        let route = finder.findCheapestRoute(from: "D", to: "A")
        XCTAssertNil(route)
    }

    private func dummyCoords() -> Coordinates {
        return Coordinates(
            from: Location(lat: 0, long: 0),
            to: Location(lat: 0, long: 0)
        )
    }
}
