import 'package:firebase_remote_config/firebase_remote_config.dart';
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

  const MapState({
    required this.isDarkMode,
    this.mapboxUrl = 'mapbox://styles/map23travel/cm16hxoxf01xr01pb1qfqgx5a',
    required this.userLocation,
    this.availableStyles = const [],
    this.points = const [],
  });

  MapState copyWith({
    bool? isDarkMode,
    String? mapboxUrl,
    LatLng? userLocation,
    List<Map<String, String>>? availableStyles,
    List<Map<String, dynamic>>? points,
  }) {
    return MapState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      mapboxUrl: mapboxUrl ?? this.mapboxUrl,
      userLocation: userLocation ?? this.userLocation,
      availableStyles: availableStyles ?? this.availableStyles,
      points: points ?? this.points,
    );
  }

  @override
  List<Object?> get props =>
      [isDarkMode, mapboxUrl, userLocation, availableStyles, points];
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
    const String apiUrl = 'https://api.tap-map.net/api/feature/collection/';
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        // Decode response body with proper handling
        final decodedResponse = utf8.decode(response.bodyBytes);
        final jsonResponse = json.decode(decodedResponse);

        // Ensure we are extracting a list from the JSON response
        final List<dynamic> features = jsonResponse['features'] ?? [];

        // Convert the list of features to a list of maps
        final points = features.map((feature) {
          return Map<String, dynamic>.from(feature);
        }).toList();

        debugPrint("Points fetched: $points");
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
        fetchTimeout: const Duration(seconds: 10),
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

  String _generateMapboxUrl(bool isDarkMode, String accessToken) {
    final id = isDarkMode ? "mapbox/dark-v10" : "mapbox/light-v10";
    return "https://api.mapbox.com/styles/v1/$id/tiles/{z}/{x}/{y}?access_token=$accessToken";
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
      // Update the Mapbox URL directly with the style_url
      emit(state.copyWith(mapboxUrl: styleUrl));
      debugPrint('Updated Mapbox URL: $styleUrl');
    } catch (e) {
      debugPrint('Error updating style: $e');
    }
  }

  void toggleTheme() {
    final newMode = !state.isDarkMode;
    final mapboxUrl =
        _generateMapboxUrl(newMode, state.mapboxUrl.split('=').last);

    emit(
      state.copyWith(
        isDarkMode: newMode,
        mapboxUrl: mapboxUrl,
      ),
    );
  }
}
