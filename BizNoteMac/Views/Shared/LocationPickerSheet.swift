import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerSheet: View {
    var initialName: String
    var onConfirm: (_ name: String, _ latitude: Double?, _ longitude: Double?) -> Void
    var onCancel: () -> Void

    @State private var query: String = ""
    @State private var selectedName: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                           span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    )

    @StateObject private var searchModel = LocationSearchCompleterModel()
    @StateObject private var locationProvider = LocationProvider()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "location.picker.title", defaultValue: "위치 찾기"))
                    .font(.headline)
                Spacer()
                Button {
                    locationProvider.requestCurrentLocation { coordinate, name in
                        selectedCoordinate = coordinate
                        selectedName = name
                        query = name
                        cameraPosition = .region(
                            MKCoordinateRegion(center: coordinate,
                                               span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        )
                    }
                } label: {
                    Label(String(localized: "location.picker.useCurrent", defaultValue: "현재 위치 사용"),
                          systemImage: "location.fill")
                }
            }
            .padding(12)

            VStack(alignment: .leading, spacing: 0) {
                TextField(String(localized: "location.picker.search", defaultValue: "장소 검색"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .onChange(of: query) { _, new in searchModel.updateQuery(new) }

                if !searchModel.results.isEmpty {
                    List(searchModel.results, id: \.self) { completion in
                        Button {
                            resolve(completion)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 140)
                }
            }

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let selectedCoordinate {
                        Marker(selectedName.isEmpty
                               ? String(localized: "location.picker.selected", defaultValue: "선택한 위치")
                               : selectedName,
                               coordinate: selectedCoordinate)
                    }
                }
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        selectedCoordinate = coordinate
                        reverseGeocode(coordinate)
                    }
                }
            }
            .frame(minHeight: 260)

            HStack {
                Button(String(localized: "action.cancel")) { onCancel() }
                Spacer()
                Button(String(localized: "action.add", defaultValue: "확인")) {
                    onConfirm(selectedName.isEmpty ? query : selectedName,
                              selectedCoordinate?.latitude, selectedCoordinate?.longitude)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedName.isEmpty && query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 480, height: 520)
        .onAppear { selectedName = initialName; query = initialName }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coordinate = item.placemark.coordinate
            selectedCoordinate = coordinate
            selectedName = completion.title
            query = completion.title
            cameraPosition = .region(
                MKCoordinateRegion(center: coordinate,
                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )
            searchModel.results = []
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let name = [placemark.name, placemark.locality].compactMap { $0 }.joined(separator: ", ")
            selectedName = name.isEmpty ? "\(coordinate.latitude), \(coordinate.longitude)" : name
            query = selectedName
        }
    }
}

final class LocationSearchCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateQuery(_ text: String) {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            results = []
        } else {
            completer.queryFragment = text
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let newResults = completer.results
        Task { @MainActor in self.results = newResults }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var onResult: ((CLLocationCoordinate2D, String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestCurrentLocation(completion: @escaping (CLLocationCoordinate2D, String) -> Void) {
        onResult = completion
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let placemark = placemarks?.first
            let name = [placemark?.name, placemark?.locality].compactMap { $0 }.joined(separator: ", ")
            let finalName = name.isEmpty ? "\(coordinate.latitude), \(coordinate.longitude)" : name
            Task { @MainActor in self?.onResult?(coordinate, finalName) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
