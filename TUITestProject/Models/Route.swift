//
//  route.swift
//  TUITestApp
//
//  Created by Michael Bielodied on 31.03.2025.
//

import Foundation

struct Route {
    let connections: [Connection]
    var totalPrice: Int {
        connections.reduce(0) { $0 + $1.price }
    }
}
