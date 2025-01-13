import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:vector_tile/vector_tile.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class MapContainer extends StatefulWidget {
  final String mapboxUrl; // e.g. "mapbox://styles/your-style"
  final LatLng userLocation; // initial user location
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

/// A small holder for SymbolOptions and data
class _SymbolData {
  final SymbolOptions options;
  final Map<String, dynamic> data;

  _SymbolData(this.options, this.data);
}

class _MapContainerState extends State<MapContainer> {
  MapboxMapController? _controller;
  String? _accessToken;

  // Track the camera center and zoom so we can preserve them on rebuild
  LatLng? _savedCenter;
  double? _savedZoom;

  @override
  void initState() {
    super.initState();
    _initializeRemoteConfig();
  }

  /// Fetch the Mapbox access token from Firebase Remote Config
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
    if (_accessToken == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use the saved center/zoom if available; otherwise, fallback to widget.userLocation
    final initialCameraCenter = _savedCenter ?? widget.userLocation;
    final initialCameraZoom = _savedZoom ?? 12.0;

    return MapboxMap(
      gestureRecognizers: {
        Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
      },
      accessToken: _accessToken!,
      styleString: widget.mapboxUrl,
      initialCameraPosition: CameraPosition(
        target: initialCameraCenter,
        zoom: initialCameraZoom,
      ),
      onMapCreated: (controller) async {
        _controller = controller;
        debugPrint("Map created and controller assigned.");
        // REMOVE the marker image loading here 
        // so we don’t load it in the old style before a theme change.
      },
      onStyleLoadedCallback: () async {
        debugPrint("Style loaded. Re-adding custom marker image...");

        // Always re-add your marker image for *this* style
        if (_controller != null) {
          await _addMarkerImage(_controller!);
        }

        // 1) Marker tap handler
        _controller?.onSymbolTapped.add((symbol) async {
          debugPrint("Marker clicked: ${symbol.data}");
          _handleMarkerClick(symbol);
        });

        // 2) Add the vector tile source (so you could style it if desired)
        await _addVectorTileSource();

        // 3) Decode and place markers (example with Z=0, X=0, Y=0)
        await _decodeAndAddMarkersFromTile(zoom: 0, x: 0, y: 0);
      },

      // Whenever the user stops panning/zooming, save the new camera position
      onCameraIdle: () async {
        if (_controller != null) {
          final position = _controller!.cameraPosition;
          if (position != null) {
            setState(() {
              _savedCenter = position.target;
              _savedZoom = position.zoom;
            });
            debugPrint(
              "Camera idle. savedCenter=$_savedCenter, savedZoom=$_savedZoom",
            );
          }
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Add a Custom Marker Icon
  Future<void> _addMarkerImage(MapboxMapController controller) async {
    try {
      final byteData = await rootBundle.load("assets/marker.png");
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      await controller.addImage("custom-marker", imageBytes);
      debugPrint("Custom marker image added to style.");
    } catch (e) {
      debugPrint("Error loading marker image: $e");
    }
  }
  // #endregion

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Add the Vector Tile Source (Optional)
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
      debugPrint("Vector tile source added (ID: 'places').");
    } catch (e) {
      debugPrint("Error adding vector tile source: $e");
    }
  }
  // #endregion

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Decode PBF using `vector_tile` and Place Markers
  Future<void> _decodeAndAddMarkersFromTile({
    required int zoom,
    required int x,
    required int y,
  }) async {
    if (_controller == null) return;

    final tileUrl =
        'https://map-travel.net/tilesets/data/tiles/$zoom/$x/$y.pbf';

    try {
      final response = await http.get(Uri.parse(tileUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load tile: ${response.statusCode}');
      }

      final vectorTile = VectorTile.fromBytes(bytes: response.bodyBytes);
      final List<_SymbolData> allSymbols = [];

      for (final layer in vectorTile.layers) {
        final extent = layer.extent; // often 4096
        debugPrint(
          "Layer '${layer.name}' has extent=$extent, features=${layer.features.length}",
        );

        for (final feature in layer.features) {
          if (feature.type == VectorTileGeomType.POINT) {
            if (feature.geometryList == null) continue;
            final List<List<Offset>> allPaths =
                _decodeGeometry(feature.geometryList!);

            if (allPaths.isNotEmpty && allPaths[0].isNotEmpty) {
              final tileOffset = allPaths[0][0];
              final latLng = _tileOffsetToLatLng(
                offset: tileOffset,
                zoom: zoom,
                tileX: x,
                tileY: y,
                extent: extent.toDouble(),
              );

              final Map<String, dynamic> properties = {};
              for (int i = 0; i < feature.tags.length; i += 2) {
                final key = layer.keys[feature.tags[i]];
                final value = layer.values[feature.tags[i + 1]];
                properties[key] = _parseVectorTileValue(value);
              }
              properties['feature_id'] = feature.id;

              final symbolOptions = SymbolOptions(
                geometry: latLng,
                iconImage: 'custom-marker', // must re-add with each style
                iconSize: 0.5,
              );
              allSymbols.add(_SymbolData(symbolOptions, properties));
            }
          }
        }
      }

      await _addSymbolsInChunks(allSymbols);
    } catch (e) {
      debugPrint("Error decoding/placing markers: $e");
    }
  }

  /// Add symbols 50 at a time so we don't block the UI too long.
  Future<void> _addSymbolsInChunks(List<_SymbolData> symbols) async {
    if (_controller == null || symbols.isEmpty) return;

    const chunkSize = 10;
    for (var i = 0; i < symbols.length; i += chunkSize) {
      final chunk = symbols.sublist(i, math.min(i + chunkSize, symbols.length));

      for (final s in chunk) {
        await _controller!.addSymbol(s.options, s.data);
      }

      // Yield to the event loop (16ms ~ 1 frame at 60fps)
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }
  // #endregion

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Decode Geometry Helpers
  List<List<Offset>> _decodeGeometry(List<int> commands) {
    final paths = <List<Offset>>[];
    var currentPath = <Offset>[];
    int x = 0;
    int y = 0;
    int i = 0;

    while (i < commands.length) {
      final commandInteger = commands[i++];
      final command = commandInteger & 0x7; // lower 3 bits
      final repeat = commandInteger >> 3; // upper bits

      switch (command) {
        case 1: // MoveTo
          if (currentPath.isNotEmpty) {
            paths.add(currentPath);
          }
          currentPath = [];
          for (int r = 0; r < repeat; r++) {
            x += _decodeZigZag(commands[i++]);
            y += _decodeZigZag(commands[i++]);
            currentPath.add(Offset(x.toDouble(), y.toDouble()));
          }
          break;
        case 2: // LineTo
          for (int r = 0; r < repeat; r++) {
            x += _decodeZigZag(commands[i++]);
            y += _decodeZigZag(commands[i++]);
            currentPath.add(Offset(x.toDouble(), y.toDouble()));
          }
          break;
        case 7: // ClosePath
          // Typically for polygons
          break;
        default:
          // Unsupported command
          break;
      }
    }

    if (currentPath.isNotEmpty) {
      paths.add(currentPath);
    }
    return paths;
  }

  int _decodeZigZag(int val) => (val >> 1) ^ (-(val & 1));

  LatLng _tileOffsetToLatLng({
    required Offset offset,
    required int zoom,
    required int tileX,
    required int tileY,
    required double extent,
  }) {
    final fracX = offset.dx / extent;
    final fracY = offset.dy / extent;
    final globalX = tileX + fracX;
    final globalY = tileY + fracY;
    return _tileXYToLatLng(globalX, globalY, zoom);
  }

  LatLng _tileXYToLatLng(double x, double y, int zoom) {
    final n = math.pi - (2.0 * math.pi * y) / math.pow(2.0, zoom.toDouble());
    final lat = (180.0 / math.pi) * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    final lng = x / math.pow(2.0, zoom.toDouble()) * 360.0 - 180.0;
    return LatLng(lat, lng);
  }
  // #endregion

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Parsing VectorTileValue
  dynamic _parseVectorTileValue(VectorTileValue value) {
    if (value.stringValue != null) return value.stringValue;
    if (value.doubleValue != null) return value.doubleValue;
    if (value.intValue != null) return value.intValue;
    if (value.boolValue != null) return value.boolValue;
    return null;
  }
  // #endregion

  // ─────────────────────────────────────────────────────────────────────────────
  // #region: Marker Click Handler
  void _handleMarkerClick(Symbol symbol) {
    final props = symbol.data;
    debugPrint("Symbol tapped. Props=$props");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marker Tapped'),
        content: Text('Properties:\n${props.toString()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }
  // #endregion
}
