import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/map_controller.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

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
  double? _lastZoom;
  final double _fetchThreshold = 50;
  final double _zoomThreshold = 1.0;

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
          : GestureDetector(
              onVerticalDragUpdate: (_) {},
              child: MapboxMap(
                gestureRecognizers: {
                  Factory<PanGestureRecognizer>(() {
                    return PanGestureRecognizer()
                      ..onDown = (DragDownDetails details) {
                        print(
                          '[onDown]:\n'
                          '  localPosition: ${details.localPosition}\n'
                          '  globalPosition: ${details.globalPosition}',
                        );
                      };
                  }),
                },
                key: UniqueKey(),
                accessToken: _accessToken!,
                styleString: widget.mapboxUrl,
                initialCameraPosition: CameraPosition(
                  // target: widget.userLocation,
                  // For debugging, set a location in Phuket:
                  target: const LatLng(7.8804, 98.3923),
                  zoom: 12,
                ),
                onMapCreated: (controller) async {
                  _controller = controller;
                  context.read<MapBloc>().mapController = controller;
                  debugPrint("Map created and controller assigned.");
                  await _addMarkerImage(_controller!);
                },
                onStyleLoadedCallback: () async {
                  debugPrint(
                      "Style loaded. Adding vector tiles and markers...");
                  debugPrint("Map created and controller assigned.");

                  // Add marker click handler
                  _controller!.onSymbolTapped.add((symbol) async {
                    // Access and debug the symbol's properties
                    await _queryFeatures();
                  });

                  await _addMarkerImage(_controller!);
                  await _addVectorTileSource();
                  await _addMarkersFromVectorTiles(
                      const LatLng(7.8804, 98.3923));
                  if (context.mounted) {
                    context
                        .read<MapBloc>()
                        .emit(context.read<MapBloc>().state.copyWith(
                              isLoading: false,
                            ));
                  }
                },
                onCameraIdle: _handleCameraIdle,
                trackCameraPosition: true,
              ),
            ),
    );
  }

  void _handleCameraIdle() async {
    if (_controller == null) return;

    // Get the new camera position
    final camPos = await _controller!.cameraPosition;
    final newCenter = camPos?.target;
    final newZoom = camPos?.zoom;

    if (newCenter == null || newZoom == null) return;

    // If first time, initialize center and zoom
    if (_lastCenter == null || _lastZoom == null) {
      _lastCenter = newCenter;
      _lastZoom = newZoom;
      return;
    }

    // Calculate distance from last center and zoom difference
    final distanceMoved = _calculateDistanceInMeters(_lastCenter!, newCenter);
    final zoomDifference = (newZoom - _lastZoom!).abs();
    debugPrint(
        "Map moved $distanceMoved meters and zoom changed by $zoomDifference.");

    // If either threshold exceeded, re-fetch
    if (distanceMoved > _fetchThreshold || zoomDifference > _zoomThreshold) {
      debugPrint(
          "Threshold exceeded (distance: $distanceMoved, zoom: $zoomDifference) => re-fetching data");
      _lastCenter = newCenter;
      _lastZoom = newZoom;
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
          maxzoom: 12,
        ),
      );

      // Add a layer using the vector tile source
      // await _controller!.addLayer(
      //   'places-layer', // Layer ID
      //   'places', // Source ID
      //   SymbolLayerProperties(
      //     iconImage:
      //         '{marker_type}', // Use the `marker_type` property for icons
      //     textField: '{name}', // Use the `name` property for text
      //     textSize: 14,
      //     textColor: "#ffffff",
      //     iconSize: 0.5,
      //     visibility: 'visible',
      //   ),
      // );

      debugPrint("Vector tile source with clustering added successfully.");
    } catch (e) {
      debugPrint("Error adding vector tile source: $e");
    }
  }

  Future<void> _addMarkersFromVectorTiles(LatLng location) async {
    if (_controller == null) return;

    try {
      debugPrint("Attempting to fetch features for the current viewport...");

      // Get the bounds of the current viewport
      final bounds = await _controller!.getVisibleRegion();

      // Query features for the entire viewport bounds
      final features = await _controller!.queryRenderedFeaturesInRect(
        Rect.fromLTRB(
          0,
          0,
          MediaQuery.of(context).size.width,
          MediaQuery.of(context).size.height,
        ),
        [], // Filter to the specific layer
        null, // No additional filter
      );

      // Print the number of features
      debugPrint("Fetched ${features.length} features.");

      // Process each feature
      for (var feature in features) {
        // debugPrint("The feature is: $feature");
        if (feature is Map) {
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final geometryType = geometry['type'] as String?;
            final coordinates = geometry['coordinates'];

            if (geometryType != null && coordinates != null) {
              await _processGeometry(
                  geometryType, coordinates, feature, geometry);
            } else {
              debugPrint("Invalid geometry or coordinates. Skipping...");
            }
          }
        } else {
          debugPrint("Unexpected feature format. Skipping...");
        }
      }

      debugPrint("All features processed successfully.");
    } catch (e) {
      debugPrint("Error fetching features: $e");
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
        await MapController(_controller!).handlePointGeometry(coords, feature);
        break;

      case 'MultiPoint':
        await MapController(_controller!)
            .handleMultiPointGeometry(coords, feature);
        break;

      case 'LineString':
        // MapController(_controller!).handleLineStringGeometry(coords, feature);
        break;

      case 'MultiLineString':
        // MapController(_controller!).handleMultiLineStringGeometry(coords, feature);
        break;

      case 'Polygon':
        // MapController(_controller!).handlePolygonGeometry(coords, feature);
        break;

      case 'MultiPolygon':
        // MapController(_controller!).handleMultiPolygonGeometry(coords, feature);
        break;

      case 'GeometryCollection':
        // Pass the same geometryMap here
        // MapController(_controller!).handleGeometryCollectionGeometry(geometryMap, feature);
        break;

      default:
        debugPrint("Unsupported geometry type: $geometryType. Skipping...");
    }
  }

  Future<void> _queryFeatures() async {
    if (_controller == null) return;

    try {
      final List<dynamic> features =
          await _controller!.queryRenderedFeaturesInRect(
        Rect.fromLTRB(
          0,
          0,
          MediaQuery.of(context).size.width,
          MediaQuery.of(context).size.height,
        ),
        ['places-layer'], // Specify your layer ID here
        null, // Additional filter expression for properties
      );

      for (var feature in features) {
        debugPrint("The feature is: $feature");

        if (feature is Map) {
          final properties = feature['properties'] as Map<String, dynamic>?;
          if (properties != null) {
            final featureId = properties['id'];
            final featureName = properties['name'];
            debugPrint("Feature ID: $featureId, Name: $featureName");
          } else {
            debugPrint("Feature has no properties.");
          }
        } else {
          debugPrint("Unexpected feature format.");
        }
      }
    } catch (e) {
      debugPrint("Error querying features: $e");
    }
  }

  // @override
  // void dispose() {
  //   _controller?.dispose();
  //   super.dispose();
  // }
}
