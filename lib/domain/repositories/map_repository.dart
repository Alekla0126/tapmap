import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:tap_map_app/data/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';


class MapRepository {
  // Fetches the Mapbox Access Token from Firebase Remote Config
  Future<String?> fetchRemoteConfigAccessToken() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(days: 1),
      minimumFetchInterval: const Duration(seconds: 30),
    ));
    await remoteConfig.fetchAndActivate();
    final token = remoteConfig.getString('mapbox_access_token');
    if (token.isEmpty) {
      return null;
    }
    return token;
  }

  // Fetches user location using Geolocator
  Future<LatLng> fetchUserLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  // Fetches available map styles from an API
  Future<List<Map<String, String>>> fetchMapStyles() async {
    const String apiUrl = ApiConstants.styles;
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      final styles = json.decode(decodedResponse) as List<dynamic>;
      return styles.map((style) {
        return {
          'id': style['id'].toString(),
          'name': style['name'].toString(),
          'style_url': style['style_url'].toString(),
        };
      }).toList();
    } else {
      debugPrint('Failed to fetch styles: ${response.statusCode}');
      return [];
    }
  }

  // Fetches points from an API or uses cached data if available
  Future<List<Map<String, dynamic>>> fetchPoints() async {
    const String apiUrl = ApiConstants.featureCollection;
    final prefs = await SharedPreferences.getInstance();

    // Check cache
    final cachedData = prefs.getString('cached_points');
    final cachedTimestamp = prefs.getInt('cached_timestamp');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // If cached points exist and are younger than 1 hour (3600000 ms)
    if (cachedData != null &&
        cachedTimestamp != null &&
        currentTime - cachedTimestamp < 3600000) {
      debugPrint('Using cached points.');
      final jsonResponse = json.decode(cachedData) as Map<String, dynamic>;
      final features = jsonResponse['features'] as List<dynamic>? ?? [];
      return features.map((f) => Map<String, dynamic>.from(f)).toList();
    }

    // Otherwise, fetch new data
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      final jsonResponse = json.decode(decodedResponse) as Map<String, dynamic>;
      final features = jsonResponse['features'] as List<dynamic>? ?? [];
      final points = features.map((f) => Map<String, dynamic>.from(f)).toList();

      // Cache new data
      await prefs.setString('cached_points', decodedResponse);
      await prefs.setInt('cached_timestamp', currentTime);
      debugPrint('Fetched and cached new points.');

      return points;
    } else {
      debugPrint('Failed to fetch points. Status: ${response.statusCode}');
      return [];
    }
  }

  // Clears cached points from SharedPreferences
  Future<void> clearCachedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('cached_points');
    prefs.remove('cached_timestamp');
    debugPrint('Saved points cleared from cache.');
  }
}
