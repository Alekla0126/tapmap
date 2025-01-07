import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'dart:convert';

// State class for the MapBloc
class MapState extends Equatable {
  final bool isDarkMode;
  final String mapboxUrl;
  final LatLng userLocation;
  final List<Map<String, String>> availableStyles;
  final List<Map<String, dynamic>> points;
  final bool isLoading; // New property

  const MapState({
    required this.isDarkMode,
    this.mapboxUrl = 'mapbox://styles/v1/mapbox/light-v11',
    required this.userLocation,
    this.availableStyles = const [],
    this.points = const [],
    this.isLoading = false, // Default to false
  });

  MapState copyWith({
    bool? isDarkMode,
    String? mapboxUrl,
    LatLng? userLocation,
    List<Map<String, String>>? availableStyles,
    List<Map<String, dynamic>>? points,
    bool? isLoading,
  }) {
    return MapState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      mapboxUrl: mapboxUrl ?? this.mapboxUrl,
      userLocation: userLocation ?? this.userLocation,
      availableStyles: availableStyles ?? this.availableStyles,
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props =>
      [isDarkMode, mapboxUrl, userLocation, availableStyles, points, isLoading];
}

// MapBloc class
class MapBloc extends Cubit<MapState> {
  int _currentStyleIndex = 0;
  MapboxMapController? mapController;

  MapBloc()
      : super(
          const MapState(
            isDarkMode: false,
            mapboxUrl: 'mapbox://styles/map23travel/cm16hxoxf01xr01pb1qfqgx5a',
            userLocation: LatLng(0, 0),
          ),
        ) {
    _initializeRemoteConfig();
    _initializeUserLocation();
    fetchMapStyles();
    // _initializePoints();
  }

  // Points are being initialize
  Future<void> _initializePoints() async {
    emit(state.copyWith(isLoading: true)); // Indicate loading
    // await fetchPoints(); // Fetch the points
    emit(state.copyWith(isLoading: false)); // Stop loading
  }

  // Getter for current style index
  int get currentStyleIndex => _currentStyleIndex;

  // Setter to update the current style index
  void setStyleIndex(int index) {
    _currentStyleIndex = index;
  }

  Future<void> fetchPoints() async {
    const String apiUrl = 'https://api.tap-map.net/api/feature/collection/';
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cached points exist and are not expired
      final cachedData = prefs.getString('cached_points');
      final cachedTimestamp = prefs.getInt('cached_timestamp');
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (cachedData != null &&
          cachedTimestamp != null &&
          currentTime - cachedTimestamp < 3600000) {
        // Use cached data if within 1 hour
        debugPrint('Using cached points.');
        final jsonResponse = json.decode(cachedData);
        final List<dynamic> features = jsonResponse['features'] ?? [];
        final points = features
            .map((feature) => Map<String, dynamic>.from(feature))
            .toList();

        emit(state.copyWith(points: points));
        return;
      }

      // Fetch new data from API
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        final jsonResponse = json.decode(decodedResponse);
        final List<dynamic> features = jsonResponse['features'] ?? [];
        final points = features
            .map((feature) => Map<String, dynamic>.from(feature))
            .toList();

        emit(state.copyWith(points: points));

        // Cache the new data and timestamp
        await prefs.setString('cached_points', decodedResponse);
        await prefs.setInt('cached_timestamp', currentTime);

        debugPrint('Fetched and cached new points.');
      } else {
        debugPrint('Failed to fetch points. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching points: $e');
    }
  }

  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(days: 1),
        minimumFetchInterval: const Duration(seconds: 30),
      ));

      await remoteConfig.fetchAndActivate();
      final accessToken = remoteConfig.getString('mapbox_access_token');
      //debugPrint("Access token: $accessToken");

      if (state.mapboxUrl.isEmpty) {
        emit(state.copyWith(
            mapboxUrl:
                'mapbox://styles/map23travel/cm16hxoxf01xr01pb1qfqgx5a'));
      }
    } catch (e) {
      //debugPrint("Error fetching remote config: $e");
    }
  }

  Future<void> _initializeUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      emit(
        state.copyWith(
          userLocation: LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      //debugPrint("Error fetching user location: $e");
    }
  }

  Future<void> fetchMapStyles() async {
    const String apiUrl = 'https://api.tap-map.net/api/styles/';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        // Ensure proper UTF-8 decoding
        final decodedResponse = utf8.decode(response.bodyBytes);
        final styles = json.decode(decodedResponse) as List;

        //debugPrint("Styles fetched: $styles");
        final availableStyles = styles.map((style) {
          return {
            'id': style['id'].toString(),
            'name': style['name'].toString(),
            'style_url': style['style_url'].toString(),
          };
        }).toList();

        if (availableStyles.isNotEmpty) {
          emit(state.copyWith(availableStyles: availableStyles));
        }
      } else {
        //debugPrint('Failed to fetch styles: ${response.body}');
      }
    } catch (e) {
      //debugPrint('Error fetching styles: $e');
    }
  }

  void updateStyle(String newStyleUrl) {
    emit(state.copyWith(mapboxUrl: newStyleUrl, isLoading: true));

    // Reset `isLoading` after a delay to allow style change
    Future.delayed(const Duration(seconds: 1), () {
      emit(state.copyWith(isLoading: false));
    });
  }

  void toggleTheme() {
    final newMode = !state.isDarkMode;
    final newStyle = newMode
        ? "mapbox://styles/v1/mapbox/dark-v11"
        : "mapbox://styles/v1/mapbox/light-v11";
    // Emit loading state
    emit(state.copyWith(isLoading: true));
    // Update the state immediately without delay
    emit(
      state.copyWith(
        isDarkMode: newMode,
        mapboxUrl: newStyle,
        isLoading: false,
      ),
    );
    //debugPrint("Toggling theme. New mode: $newMode, New style: $newStyle");
  }

  Future<void> clearSavedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('points');
    //debugPrint("Saved points cleared.");
  }
}
