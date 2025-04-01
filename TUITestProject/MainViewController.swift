//
//  ViewController.swift
//  TUITestProject
//
//  Created by Michael Bielodied on 01.04.2025.
//

import UIKit
import MapKit
import Combine

final class MainViewController: UIViewController {
    private let viewModel = RouteViewModel()
    private var subscriptions = Set<AnyCancellable>()

    private let fromField = UITextField()
    private let toField = UITextField()
    private let resultLabel = UILabel()
    private let mapView = MKMapView()
    private let findButton = UIButton(type: .system)
    private let suggestionsTableView = UITableView()
    private var filteredCities: [City] = []
    private var activeTextField: UITextField?
    private let suggestionsContainer = UIView()

    private var cities: [City] = []
    private var fromSelected: City?
    private var toSelected: City?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }
}

// MARK: - Setup UI & Binding
extension MainViewController {
    private func setupUI() {
        view.backgroundColor = .systemBackground

        [fromField, toField, findButton, resultLabel, mapView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        suggestionsContainer.translatesAutoresizingMaskIntoConstraints = false
        suggestionsContainer.backgroundColor = .clear
        view.addSubview(suggestionsContainer)

        suggestionsTableView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        suggestionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        suggestionsTableView.isScrollEnabled = true
        suggestionsTableView.allowsSelection = true
        suggestionsTableView.backgroundColor = .white
        suggestionsContainer.addSubview(suggestionsTableView)

        fromField.placeholder = "From"
        toField.placeholder = "To"
        fromField.borderStyle = .roundedRect
        toField.borderStyle = .roundedRect

        findButton.setTitle("Find Cheapest Route", for: .normal)
        findButton.addTarget(self, action: #selector(findTapped), for: .touchUpInside)

        resultLabel.numberOfLines = 0
        mapView.layer.cornerRadius = 8
        mapView.clipsToBounds = true
        mapView.delegate = self

        NSLayoutConstraint.activate([
            fromField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            fromField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fromField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            toField.topAnchor.constraint(equalTo: fromField.bottomAnchor, constant: 12),
            toField.leadingAnchor.constraint(equalTo: fromField.leadingAnchor),
            toField.trailingAnchor.constraint(equalTo: fromField.trailingAnchor),

            findButton.topAnchor.constraint(equalTo: toField.bottomAnchor, constant: 12),
            findButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            resultLabel.topAnchor.constraint(equalTo: findButton.bottomAnchor, constant: 12),
            resultLabel.leadingAnchor.constraint(equalTo: fromField.leadingAnchor),
            resultLabel.trailingAnchor.constraint(equalTo: fromField.trailingAnchor),

            mapView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 12),
            mapView.leadingAnchor.constraint(equalTo: fromField.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: fromField.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            suggestionsContainer.topAnchor.constraint(equalTo: toField.bottomAnchor, constant: 4),
            suggestionsContainer.leadingAnchor.constraint(equalTo: fromField.leadingAnchor),
            suggestionsContainer.trailingAnchor.constraint(equalTo: fromField.trailingAnchor),
            suggestionsContainer.heightAnchor.constraint(equalToConstant: 200),

            suggestionsTableView.topAnchor.constraint(equalTo: suggestionsContainer.topAnchor),
            suggestionsTableView.leadingAnchor.constraint(equalTo: suggestionsContainer.leadingAnchor),
            suggestionsTableView.trailingAnchor.constraint(equalTo: suggestionsContainer.trailingAnchor),
            suggestionsTableView.bottomAnchor.constraint(equalTo: suggestionsContainer.bottomAnchor),
        ])

        fromField.accessibilityIdentifier = "From"
        toField.accessibilityIdentifier = "To"
        findButton.accessibilityIdentifier = "Find Cheapest Route"
        resultLabel.accessibilityIdentifier = "resultLabel"

        fromField.delegate = self
        toField.delegate = self

        fromField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        toField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

        suggestionsContainer.isHidden = true
        view.bringSubviewToFront(suggestionsContainer)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func bindViewModel() {
        viewModel.$allCities
            .sink { [weak self] cities in
                self?.cities = cities
            }
            .store(in: &subscriptions)

        viewModel.$route
            .sink { [weak self] route in
                self?.updateUIWithRoute(route)
            }
            .store(in: &subscriptions)

        viewModel.$errorMessage
            .sink { [weak self] message in
                if let message = message {
                    self?.resultLabel.text = message
                    self?.mapView.removeOverlays(self?.mapView.overlays ?? [])
                }
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Actions
extension MainViewController {
    @objc private func dismissKeyboard() {
        view.endEditing(true)
        suggestionsContainer.isHidden = true
    }

    @objc private func findTapped() {
        guard let fromText = fromField.text, !fromText.isEmpty,
              let toText = toField.text, !toText.isEmpty else {
            resultLabel.text = "Please fill both fields."
            return
        }

        viewModel.fromCity = cities.first { $0.name.caseInsensitiveCompare(fromText) == .orderedSame }
        viewModel.toCity = cities.first { $0.name.caseInsensitiveCompare(toText) == .orderedSame }

        viewModel.findRoute()
        drawRouteBetweenCities(from: fromText, to: toText)
    }

    private func updateUIWithRoute(_ route: Route?) {
        guard let route = route else { return }
        resultLabel.text = "Total Price: \(route.totalPrice) €"

        mapView.removeOverlays(mapView.overlays)

        let coordinates = route.connections.map { $0.coordinates.from.coordinate } + [route.connections.last!.coordinates.to.coordinate]
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: .init(top: 20, left: 20, bottom: 20, right: 20), animated: true)
    }

    private func drawRouteBetweenCities(from cityName1: String, to cityName2: String) {
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
                print("⚠️ Failed to find coordinates for cities")
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

// MARK: - Delegates
extension MainViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        suggestionsContainer.isHidden = true
        return true
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        activeTextField = textField

        guard let text = textField.text?.lowercased(), !text.isEmpty else {
            filteredCities = []
            suggestionsContainer.isHidden = true
            return
        }

        filteredCities = cities.filter { $0.name.lowercased().contains(text) }
        suggestionsTableView.reloadData()
        suggestionsContainer.isHidden = filteredCities.isEmpty
    }
}

extension MainViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredCities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let city = filteredCities[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = city.name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let city = filteredCities[indexPath.row]
        if let textField = activeTextField {
            textField.text = city.name
            textField.resignFirstResponder()
        }

        suggestionsContainer.isHidden = true
        filteredCities = []

        if activeTextField === fromField {
            viewModel.fromCity = city
        } else if activeTextField === toField {
            viewModel.toCity = city
        }
    }
}
