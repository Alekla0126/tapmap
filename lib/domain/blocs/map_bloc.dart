import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
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
    this.mapboxUrl = 'mapbox://styles/mapbox/light-v11',
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
  MapBloc()
      : super(
          const MapState(
            isDarkMode: false,
            mapboxUrl: '',
            userLocation: LatLng(0, 0),
          ),
        ) {
    _initializeRemoteConfig();
    _initializeUserLocation();
    fetchMapStyles();
    fetchPoints();
  }

  Future<void> fetchPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if points are already saved
      final savedPoints = prefs.getString('points');
      if (savedPoints != null) {
        // Decode saved points
        final decodedPoints = json.decode(savedPoints) as List<dynamic>;
        final points = decodedPoints.map((point) {
          return Map<String, dynamic>.from(point as Map);
        }).toList();

        emit(state.copyWith(points: points));
        debugPrint("Loaded points from SharedPreferences: $points");
        return;
      }

      // Fetch points from API
      const String apiUrl = 'https://api.tap-map.net/api/feature/collection/';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        final jsonResponse = json.decode(decodedResponse);

        final List<dynamic> features = jsonResponse['features'] ?? [];
        final points = features.map((feature) {
          return Map<String, dynamic>.from(feature);
        }).toList();

        // Save points in SharedPreferences
        prefs.setString('points', json.encode(points));

        debugPrint("Points fetched and saved: $points");
        emit(state.copyWith(points: points));
      } else {
        debugPrint('Failed to fetch points: ${response.body}');
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
      debugPrint("Access token: $accessToken");

      if (state.mapboxUrl.isEmpty) {
        emit(state.copyWith(mapboxUrl: _generateMapboxUrl(false, accessToken)));
      }
    } catch (e) {
      debugPrint("Error fetching remote config: $e");
    }
  }

  String _generateMapboxUrl(bool isDarkMode, String accessToken) {
    if (isDarkMode) {
      return "mapbox://styles/mapbox/dark-v11";
    }
    return "mapbox://styles/mapbox/light-v11";
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
      debugPrint("Error fetching user location: $e");
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

        debugPrint("Styles fetched: $styles");
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
        debugPrint('Failed to fetch styles: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching styles: $e');
    }
  }

  void updateStyle(String styleUrl) {
    try {
      debugPrint('Received style URL: $styleUrl');
      // Emit loading state
      emit(state.copyWith(isLoading: true));
      // Update the Mapbox URL
      emit(state.copyWith(mapboxUrl: styleUrl));
      debugPrint('Updated Mapbox URL: $styleUrl');
    } catch (e) {
      debugPrint('Error updating style: $e');
    }
  }

  void toggleTheme() {
    final newMode = !state.isDarkMode;
    final newStyle = newMode
        ? "mapbox://styles/mapbox/dark-v11"
        : "mapbox://styles/mapbox/light-v11";
    // Emit loading state
    emit(state.copyWith(isLoading: true));
    // Simulate rendering delay (for demonstration; remove in production)
    Future.delayed(const Duration(milliseconds: 500), () {
      emit(
        state.copyWith(
          isDarkMode: newMode,
          mapboxUrl: newStyle,
          isLoading: false, // Reset loading state
        ),
      );
    });
    debugPrint("Toggling theme. New mode: $newMode, New style: $newStyle");
  }

  Future<void> clearSavedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('points');
    debugPrint("Saved points cleared.");
  }
}
