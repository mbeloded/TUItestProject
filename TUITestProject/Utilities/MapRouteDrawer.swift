//
//  MapRouteDrawer.swift
//  TUITestProject
//
//  Created by Michael Bielodied on 01.04.2025.
//

import MapKit
import CoreLocation

final class MapRouteDrawer {

    private let mapView: MKMapView

    init(mapView: MKMapView) {
        self.mapView = mapView
    }

    func drawRouteBetweenCities(from cityName1: String, to cityName2: String) {
        let geocoder = CLGeocoder()
        let group = DispatchGroup()

        var coord1: CLLocationCoordinate2D?
        var coord2: CLLocationCoordinate2D?

        group.enter()
        geocoder.geocodeAddressString(cityName1) { placemarks, _ in
            coord1 = placemarks?.first?.location?.coordinate
            group.leave()
        }

        group.enter()
        geocoder.geocodeAddressString(cityName2) { placemarks, _ in
            coord2 = placemarks?.first?.location?.coordinate
            group.leave()
        }

        group.notify(queue: .main) {
            guard let from = coord1, let to = coord2 else {
                print("⚠️ Could not resolve coordinates")
                return
            }

            self.mapView.removeAnnotations(self.mapView.annotations)
            self.mapView.removeOverlays(self.mapView.overlays)

            let fromAnnotation = MKPointAnnotation()
            fromAnnotation.title = cityName1
            fromAnnotation.coordinate = from

            let toAnnotation = MKPointAnnotation()
            toAnnotation.title = cityName2
            toAnnotation.coordinate = to

            self.mapView.addAnnotations([fromAnnotation, toAnnotation])

            let polyline = MKPolyline(coordinates: [from, to], count: 2)
            self.mapView.addOverlay(polyline)

            self.mapView.setVisibleMapRect(polyline.boundingMapRect,
                                           edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40),
                                           animated: true)
        }
    }
}
