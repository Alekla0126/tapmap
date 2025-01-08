import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:math';

class MapContainer extends StatefulWidget {
  final String mapboxUrl;
  final LatLng userLocation;
  final bool isLoading;

  const MapContainer({
    required this.mapboxUrl,
    required this.userLocation,
    required this.isLoading,
    Key? key,
  }) : super(key: key);

  @override
  State<MapContainer> createState() => _MapContainerState();
}

class _MapContainerState extends State<MapContainer> {
  MapboxMapController? _controller;
  String? _accessToken;

  // Track last center and threshold for fetching
  LatLng? _lastCenter;
  final double _fetchThreshold = 10;

  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  Future<void> _initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(days: 1),
      ));

      await remoteConfig.fetchAndActivate();
      final token = remoteConfig.getString('mapbox_access_token');

      if (token.isNotEmpty) {
        setState(() {
          _accessToken = token;
        });
        debugPrint("Mapbox access token retrieved successfully.");
      } else {
        throw Exception("Mapbox access token is empty.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load map configuration.")),
      );
      debugPrint("Error fetching Mapbox access token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: _accessToken == null || _accessToken!.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : MapboxMap(
              key: UniqueKey(),
              accessToken: _accessToken!,
              styleString: widget.mapboxUrl,
              initialCameraPosition: CameraPosition(
                // target: widget.userLocation,
                // For debugging, set a location in Phuket:
                target: const LatLng(7.8804, 98.3923),
                zoom: 15,
              ),
              onMapCreated: (controller) async {
                _controller = controller;
                context.read<MapBloc>().mapController = controller;
                debugPrint("Map created and controller assigned.");
                await _addMarkerImage(_controller!);
              },
              onStyleLoadedCallback: () async {
                debugPrint("Style loaded. Adding vector tiles and markers...");
                await _addMarkerImage(_controller!);
                await _addVectorTileSource();
                await _addMarkersFromVectorTiles(const LatLng(7.8804, 98.3923));
                if (context.mounted) {
                  context
                      .read<MapBloc>()
                      .emit(context.read<MapBloc>().state.copyWith(
                            isLoading: false,
                          ));
                }
              },
              onCameraIdle: _handleCameraIdle, // Listen for camera idle
            ),
    );
  }

  void _handleCameraIdle() async {
    if (_controller == null) return;

    // Get the new center
    final camPos = await _controller!.cameraPosition;
    final newCenter = camPos?.target;

    if (_lastCenter == null) {
      _lastCenter = newCenter;
      return;
    }

    // Calculate distance from last center
    final distanceMoved = _calculateDistanceInMeters(_lastCenter!, newCenter!);
    debugPrint("Map moved $distanceMoved meters from old center.");

    // If threshold exceeded, re-fetch
    if (distanceMoved > _fetchThreshold) {
      debugPrint("Moved more than $_fetchThreshold meters => re-fetch data");
      _lastCenter = newCenter;
      await _addMarkersFromVectorTiles(newCenter);
    }
  }

  double _calculateDistanceInMeters(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // in meters
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

  double _degreesToRadians(double deg) => deg * math.pi / 180;

  Future<void> _addMarkerImage(MapboxMapController controller) async {
    try {
      final byteData = await rootBundle.load("assets/marker.png");
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      await controller.addImage("custom-marker", imageBytes);
      debugPrint("Marker image added successfully.");
    } catch (e) {
      debugPrint("Error loading marker image: $e");
    }
  }

  Future<void> _addVectorTileSource() async {
    if (_controller == null) return;

    try {
      await _controller!.addSource(
        'places',
        VectorSourceProperties(
          tiles: ['https://map-travel.net/tilesets/data/tiles/{z}/{x}/{y}.pbf'],
          minzoom: 0,
          maxzoom: 18,
        ),
      );
      debugPrint("Vector tile source with clustering added successfully.");
    } catch (e) {
      debugPrint("Error adding vector tile source: $e");
    }
  }

  Future<void> _addMarkersFromVectorTiles(LatLng location) async {
    if (_controller == null) return;

    try {
      debugPrint("Attempting to fetch features...");

      // Convert user location (or debugging point) to screen coordinates
      final screenPoint = await _controller!.toScreenLocation(location);

      final features = await _controller!.queryRenderedFeatures(
        Point<double>(
          screenPoint.x.toDouble(),
          screenPoint.y.toDouble(),
        ),
        [], // No layer ID filter
        null, // No filter
      );

      debugPrint("Features fetched: ${features}");

      // Process each feature
      for (var feature in features) {
        if (feature is Map) {
          final geometryMap = feature['geometry'] as Map<String, dynamic>?;
          if (geometryMap == null) {
            debugPrint("Feature has no geometry. Skipping...");
            continue;
          }

          final geometryType = geometryMap['type'] as String?;
          final coords = geometryMap['coordinates'];

          if (geometryType == null || coords == null) {
            debugPrint("Invalid geometry type or coordinates. Skipping...");
            continue;
          }

          await _processGeometry(geometryType, coords, feature, geometryMap);
        } else {
          debugPrint("Unexpected feature format. Skipping...");
        }
      }

      debugPrint("All markers added successfully.");
    } catch (e) {
      debugPrint("Error adding markers from vector tiles: $e");
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
        await _handlePointGeometry(coords, feature);
        break;

      case 'MultiPoint':
        await _handleMultiPointGeometry(coords, feature);
        break;

      case 'LineString':
        await _handleLineStringGeometry(coords, feature);
        break;

      case 'MultiLineString':
        await _handleMultiLineStringGeometry(coords, feature);
        break;

      case 'Polygon':
        // await _handlePolygonGeometry(coords, feature);
        break;

      case 'MultiPolygon':
        //await _handleMultiPolygonGeometry(coords, feature);
        break;

      case 'GeometryCollection':
        // Pass the same geometryMap here
        await _handleGeometryCollectionGeometry(geometryMap, feature);
        break;

      default:
        debugPrint("Unsupported geometry type: $geometryType. Skipping...");
    }
  }

  Future<void> _handleMultiPointGeometry(dynamic coords, Map feature) async {
    if (coords is List) {
      for (var point in coords) {
        await _handlePointGeometry(point, feature);
      }
    } else {
      debugPrint("Invalid MultiPoint coordinates structure. Skipping...");
    }
  }

  Future<void> _handleMultiPolygonGeometry(dynamic coords, Map feature) async {
    if (coords is List) {
      for (var polygon in coords) {
        await _handlePolygonGeometry(polygon, feature);
      }
    } else {
      debugPrint("Invalid MultiPolygon structure. Skipping...");
    }
  }

  Future<void> _handleGeometryCollectionGeometry(
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

  Future<void> _handlePointGeometry(dynamic coords, Map feature) async {
    if (coords is List && coords.length == 2) {
      final lng = coords[0] is num ? coords[0] as double : null;
      final lat = coords[1] is num ? coords[1] as double : null;

      if (lng == null || lat == null) {
        debugPrint("Invalid Point coordinates. Skipping...");
        return;
      }

      final properties = feature['properties'] as Map<String, dynamic>?;
      final id = properties?['id']?.toString() ?? '';
      final name = properties?['name']?.toString() ?? 'Unnamed';

      debugPrint("Adding marker at LatLng($lat, $lng) with ID: $id");

      await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: "custom-marker",
          iconSize: 0.5,
          textOffset: const Offset(0, 1),
          textColor: "#000000",
        ),
      );
    } else {
      debugPrint("Invalid Point coordinates structure. Skipping...");
    }
  }

  Future<void> _handleLineStringGeometry(dynamic coords, Map feature) async {
    if (coords is List && coords.isNotEmpty) {
      // Convert each [lng, lat] pair to LatLng
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

      if (lineLatLngs.length < 2) {
        debugPrint("Invalid LineString coordinates. Need at least two points.");
        return;
      }

      // Draw the line
      await _controller?.addLine(
        LineOptions(
          geometry: lineLatLngs,
          lineColor: "#3BB2D0", // Pick your color
          lineWidth: 2.0, // Pick your width
          lineOpacity: 1.0,
        ),
      );

      // Optionally, place a marker at the midpoint
      final start = lineLatLngs.first;
      final end = lineLatLngs.last;
      final midLat = (start.latitude + end.latitude) / 2;
      final midLng = (start.longitude + end.longitude) / 2;

      debugPrint(
          "Adding LineString midpoint marker at LatLng($midLat, $midLng)");
      await _controller?.addSymbol(
        SymbolOptions(
          geometry: LatLng(midLat, midLng),
          iconImage: "custom-marker",
          iconSize: 0.5,
          textOffset: const Offset(0, 1),
          textColor: "#000000",
        ),
      );
    } else {
      debugPrint("Invalid LineString coordinates structure. Skipping...");
    }
  }

  Future<void> _handlePolygonGeometry(dynamic coords, Map feature) async {
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

        await _controller!.addSymbol(
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

  Future<void> _handleMultiLineStringGeometry(
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

        debugPrint(
            "Adding marker for flattened MultiLineString at LatLng($centerLat, $centerLng)");

        await _controller!.addSymbol(
          SymbolOptions(
            geometry: LatLng(centerLat, centerLng),
            iconImage: "custom-marker",
            iconSize: 0.5,
            textOffset: const Offset(0, 1),
            textColor: "#000000",
          ),
        );
      } else {
        debugPrint(
            "No valid coordinates found in MultiLineString. Skipping...");
      }
    } else {
      debugPrint("Invalid MultiLineString structure. Skipping...");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
