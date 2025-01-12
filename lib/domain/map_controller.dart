import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class MapController {
  MapboxMapController controller;
  String? accessToken;
  LatLng? lastCenter;
  final double fetchThreshold = 50;

  MapController(this.controller);

  Future<void> initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(days: 1),
      ));

      await remoteConfig.fetchAndActivate();
      final token = remoteConfig.getString('mapbox_access_token');

      if (token.isNotEmpty) {
        accessToken = token;
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      throw Exception("Failed to load map configuration: $e");
    }
  }

  Future<void> _processGeometry(
    String geometryType,
    dynamic coords,
    Map feature,
    Map<String, dynamic> geometryMap,
  ) async {
    switch (geometryType) {
      case 'Point':
        await handlePointGeometry(coords, feature);
        break;
      case 'MultiPoint':
        await handleMultiPointGeometry(coords, feature);
        break;
      case 'LineString':
        await handleLineStringGeometry(coords, feature);
        break;
      case 'MultiLineString':
        await handleMultiLineStringGeometry(coords, feature);
        break;
      case 'GeometryCollection':
        await handleGeometryCollectionGeometry(geometryMap, feature);
        break;
      default:
        break;
    }
  }

  Future<void> handlePointGeometry(dynamic coords, Map feature) async {
    if (coords is List && coords.length == 2) {
      final lng = coords[0] is num ? coords[0] as double : null;
      final lat = coords[1] is num ? coords[1] as double : null;

      if (lng == null || lat == null) return;

      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: "custom-marker",
          iconSize: 0.5,
          textOffset: const Offset(0, 1),
          textColor: "#000000",
        ),
      );
    }
  }

  Future<void> handleMultiPointGeometry(dynamic coords, Map feature) async {
    if (coords is List) {
      for (var point in coords) {
        await handlePointGeometry(point, feature);
      }
    }
  }

  Future<void> handleLineStringGeometry(dynamic coords, Map feature) async {
    if (coords is List && coords.isNotEmpty) {
      final lineLatLngs = <LatLng>[];
      for (var coord in coords) {
        if (coord is List && coord.length >= 2) {
          final lng = coord[0];
          final lat = coord[1];
          if (lng is num && lat is num) {
            lineLatLngs.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }

      if (lineLatLngs.length < 2) return;

      await controller.addLine(
        LineOptions(
          geometry: lineLatLngs,
          lineColor: "#3BB2D0",
          lineWidth: 2.0,
          lineOpacity: 1.0,
        ),
      );

      final start = lineLatLngs.first;
      final end = lineLatLngs.last;
      final midLat = (start.latitude + end.latitude) / 2;
      final midLng = (start.longitude + end.longitude) / 2;

      await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(midLat, midLng),
          iconImage: "custom-marker",
          iconSize: 0.5,
          textOffset: const Offset(0, 1),
          textColor: "#000000",
        ),
      );
    }
  }

  Future<void> handleMultiLineStringGeometry(
      dynamic coords, Map feature) async {
    if (coords is List && coords.length > 1) {
      final List<List<double>> flattenedCoords = coords.expand((segment) {
        if (segment is List) {
          return segment.whereType<List>().map((pair) {
            if (pair.length == 2 && pair[0] is num && pair[1] is num) {
              return [pair[0] as double, pair[1] as double];
            }
            return null;
          }).whereType<List<double>>();
        }
        return <List<double>>[];
      }).toList();

      if (flattenedCoords.isNotEmpty) {
        final centerLat =
            flattenedCoords.map((pair) => pair[1]).reduce((a, b) => a + b) /
                flattenedCoords.length;
        final centerLng =
            flattenedCoords.map((pair) => pair[0]).reduce((a, b) => a + b) /
                flattenedCoords.length;

        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(centerLat, centerLng),
            iconImage: "custom-marker",
            iconSize: 0.5,
            textOffset: const Offset(0, 1),
            textColor: "#000000",
          ),
        );
      }
    }
  }

  Future<void> handleGeometryCollectionGeometry(
      Map<String, dynamic> geometryMap, Map feature) async {
    final geometries = geometryMap['geometries'];
    if (geometries is List) {
      for (var geom in geometries) {
        if (geom is Map) {
          final subGeometryType = geom['type'];
          final subCoords = geom['coordinates'];
          await _processGeometry(subGeometryType, subCoords, feature,
              geom as Map<String, dynamic>);
        }
      }
    }
  }

  double calculateDistanceInMeters(LatLng start, LatLng end) {
    const double earthRadius = 6371000;
    final lat1 = _degreesToRadians(start.latitude);
    final lat2 = _degreesToRadians(end.latitude);
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLng = _degreesToRadians(end.longitude - start.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> handlePolygonGeometry(dynamic coords, Map feature) async {
    if (coords is List) {
      final List<List<double>> polygonCoords = [];
      for (var pair in coords.first) {
        if (pair is List &&
            pair.length == 2 &&
            pair[0] is num &&
            pair[1] is num) {
          polygonCoords.add([pair[0] as double, pair[1] as double]);
        } else {
          debugPrint("Invalid coordinate pair in Polygon: $pair");
        }
      }

      if (polygonCoords.isNotEmpty) {
        final centroidLat =
            polygonCoords.map((pair) => pair[1]).reduce((a, b) => a + b) /
                polygonCoords.length;
        final centroidLng =
            polygonCoords.map((pair) => pair[0]).reduce((a, b) => a + b) /
                polygonCoords.length;

        debugPrint(
            "Adding marker for Polygon at LatLng($centroidLat, $centroidLng)");

        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(centroidLat, centroidLng),
            iconImage: "custom-marker",
            iconSize: 0.5,
            textOffset: const Offset(0, 1),
            textColor: "#000000",
          ),
        );
      } else {
        debugPrint("Invalid Polygon coordinates. Skipping...");
      }
    } else {
      debugPrint("Invalid Polygon coordinates structure. Skipping...");
    }
  }

  Future<void> handleMultiPolygonGeometry(dynamic coords, Map feature) async {
    if (coords is List) {
      for (var polygon in coords) {
        await handlePolygonGeometry(polygon, feature);
      }
    } else {
      debugPrint("Invalid MultiPolygon structure. Skipping...");
    }
  }

  double _degreesToRadians(double deg) => deg * math.pi / 180;
}
