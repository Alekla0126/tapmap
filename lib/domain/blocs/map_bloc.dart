import '../repositories/map_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';

// --------------------
//  MapState
// --------------------
class MapState extends Equatable {
  final bool isDarkMode;
  final String mapboxUrl;
  final LatLng userLocation;
  final List<Map<String, String>> availableStyles;
  final List<Map<String, dynamic>> points;
  final bool isLoading;
  final MapboxMapController? mapController;

  const MapState({
    required this.isDarkMode,
    this.mapboxUrl = 'mapbox://styles/v1/mapbox/light-v11',
    required this.userLocation,
    this.availableStyles = const [],
    this.points = const [],
    this.isLoading = false,
    this.mapController, 
  });

  MapState copyWith({
    bool? isDarkMode,
    String? mapboxUrl,
    LatLng? userLocation,
    List<Map<String, String>>? availableStyles,
    List<Map<String, dynamic>>? points,
    bool? isLoading,
    MapboxMapController? mapController, // Handle the new property
  }) {
    return MapState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      mapboxUrl: mapboxUrl ?? this.mapboxUrl,
      userLocation: userLocation ?? this.userLocation,
      availableStyles: availableStyles ?? this.availableStyles,
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
      mapController: mapController ?? this.mapController, // Direct assignment
    );
  }

  @override
  List<Object?> get props => [
        isDarkMode,
        mapboxUrl,
        userLocation,
        availableStyles,
        points,
        isLoading,
        // Exclude mapController from props to prevent Equatable issues
      ];
}

// --------------------
//  MapBloc
// --------------------
class MapBloc extends Cubit<MapState> {
  final MapRepository _repository;

  /// Index for which style is currently selected
  int _currentStyleIndex = 0;

  // Queue to hold pending camera movements
  final List<LatLng> _cameraMoveQueue = [];

  // -----------------------------------------------
  //  Constructor
  // -----------------------------------------------
  MapBloc(this._repository)
      : super(
          const MapState(
            isDarkMode: false,
            mapboxUrl: 'mapbox://styles/map23travel/cm16hxoxf01xr01pb1qfqgx5a',
            userLocation: LatLng(0, 0),
          ),
        ) {
    initialize();
  }

  // -----------------------------------------------
  //  Initial Setup
  // -----------------------------------------------
  Future<void> initialize() async {
    await _initializeRemoteConfig();
    await _initializeUserLocation();
    fetchMapStyles();
    // If needed, initialize points at startup
    // await _initializePoints();
  }

  // -----------------------------------------------
  //  Getter / Setter for Style Index
  // -----------------------------------------------
  int get currentStyleIndex => _currentStyleIndex;
  void setStyleIndex(int index) => _currentStyleIndex = index;
  MapboxMapController? get mapController => state.mapController;

  // -----------------------------------------------
  //  Remote Config
  // -----------------------------------------------
  Future<void> _initializeRemoteConfig() async {
    try {
      final accessToken = await _repository.fetchRemoteConfigAccessToken();
      // If the token from remote config is available, override the initial URL
      if (accessToken != null && accessToken.isNotEmpty) {
        emit(state.copyWith(mapboxUrl: accessToken));
      }
    } catch (e) {
      debugPrint("Error fetching remote config: $e");
      // We won't emit an error state to keep the map displayed,
      // but you could handle it if necessary.
    }
  }

  // -----------------------------------------------
  //  User Location
  // -----------------------------------------------
  Future<void> _initializeUserLocation() async {
    try {
      final position = await _repository.fetchUserLocation();
      emit(state.copyWith(userLocation: position));
    } catch (e) {
      debugPrint("Error fetching user location: $e");
    }
  }

  // -----------------------------------------------
  //  Map Styles
  // -----------------------------------------------
  Future<void> fetchMapStyles() async {
    emit(state.copyWith(isLoading: true));
    try {
      final styles = await _repository.fetchMapStyles();
      emit(state.copyWith(availableStyles: styles, isLoading: false));
    } catch (e) {
      debugPrint("Error fetching styles: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  void updateStyle(String newStyleUrl) {
    emit(state.copyWith(mapboxUrl: newStyleUrl, isLoading: true));
    // Simulate a short delay before indicating loading complete
    Future.delayed(const Duration(seconds: 1), () {
      emit(state.copyWith(isLoading: false));
    });
  }

  // -----------------------------------------------
  //  Points
  // -----------------------------------------------
  Future<void> _initializePoints() async {
    // Only call fetchPoints if you want them at startup
    emit(state.copyWith(isLoading: true));
    await fetchPoints();
    emit(state.copyWith(isLoading: false));
  }

  Future<void> fetchPoints() async {
    emit(state.copyWith(isLoading: true));
    try {
      final points = await _repository.fetchPoints();
      emit(state.copyWith(points: points, isLoading: false));
    } catch (e) {
      debugPrint("Error fetching points: $e");
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> clearSavedPoints() async {
    await _repository.clearCachedPoints();
    emit(state.copyWith(points: []));
  }

  // -----------------------------------------------
  //  Dark / Light Theme
  // -----------------------------------------------
  void toggleTheme() {
    final newMode = !state.isDarkMode;
    final newStyle = newMode
        ? "mapbox://styles/v1/mapbox/dark-v11"
        : "mapbox://styles/v1/mapbox/light-v11";

    // Show a quick loading indicator
    emit(state.copyWith(isLoading: true));

    // Then emit the new theme style
    emit(state.copyWith(
      isDarkMode: newMode,
      mapboxUrl: newStyle,
      isLoading: false,
    ));
  }

  // -----------------------------------------------
  //  MapController Management
  // -----------------------------------------------
  void setMapController(MapboxMapController controller) {
    emit(state.copyWith(mapController: controller));
    debugPrint("MapController has been set in MapBloc.");

    // Process any pending camera movements
    if (_cameraMoveQueue.isNotEmpty) {
      for (var target in _cameraMoveQueue) {
        moveCameraTo(target);
      }
      _cameraMoveQueue.clear();
    }
  }

  bool get isMapControllerInitialized => mapController != null;

  // -----------------------------------------------
  //  Camera Movement
  // -----------------------------------------------

  /// Moves the camera to the specified [target] location.
  Future<void> moveCameraTo(LatLng target) async {
    final controller = state.mapController;
    // if (controller == null) {
    //   debugPrint("MapController is not initialized. Queuing camera movement to $target.");
    //   _cameraMoveQueue.add(target);
    //   return;
    // }

    emit(state.copyWith(isLoading: true));

    try {
      await controller!.animateCamera(
        CameraUpdate.newLatLng(target),
      );
      debugPrint("Camera moved to: $target");
    } catch (e) {
      debugPrint("Error moving camera to $target: $e");
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}