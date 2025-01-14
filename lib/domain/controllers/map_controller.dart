import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:vector_tile/vector_tile.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class _SymbolData {
  final mapbox.SymbolOptions options;
  final Map<String, dynamic> data;
  _SymbolData(this.options, this.data);
}

class MapController {
  final double fetchThreshold = 50;
  MapboxMapController controller;
  String? accessToken;
  LatLng? lastCenter;

  MapController(this.controller);

  // -------------------------------------------------------------
  //  Marker + Vector Tile Logic
  // -------------------------------------------------------------
  Future<void> addMarkerImage(MapboxMapController controller) async {
    try {
      final byteData = await rootBundle.load("assets/marker.png");
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      await controller.addImage("custom-marker", imageBytes);
      debugPrint("Custom marker image added to style.");
    } catch (e) {
      debugPrint("Error loading marker image: $e");
    }
  }

  Future<void> addMarker(MapboxMapController controller) async {
    try {
      final byteData = await rootBundle.load("assets/marker.png");
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      await controller.addImage("custom-marker", imageBytes);
      debugPrint("Custom marker image added to style.");
    } catch (e) {
      debugPrint("Error loading marker image: $e");
    }
  }

  Future<void> addMyMarker({
    required double latitude,
    required double longitude,
    required String pngAssetPath, // Path to the PNG asset
    required String iconImageId,
  }) async {
    try {
      // 1) Load the raw PNG data from the asset
      final ByteData byteData = await rootBundle.load(pngAssetPath);
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2) Add the image to the Mapbox style (using [iconImageId] as the name)
      await controller.addImage(iconImageId, pngBytes);

      // 3) Create a symbol at the desired location
      await controller.addSymbol(
        mapbox.SymbolOptions(
          geometry: mapbox.LatLng(latitude, longitude),
          iconImage: iconImageId, // Must match the name we passed above
          iconSize: 0.04, // Adjust the scale if needed
        ),
      );
    } catch (e) {
      debugPrint("Error adding PNG marker: $e");
    }
  }

  Future<void> addVectorTileSource() async {
    try {
      await controller.addSource(
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

  Future<void> decodeAndAddMarkersFromTile({
    required int zoom,
    required int x,
    required int y,
  }) async {
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
                iconImage: 'custom-marker',
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

  /// Add symbols 10 at a time so we don't block the UI too long.
  Future<void> _addSymbolsInChunks(List<_SymbolData> symbols) async {
    if (symbols.isEmpty) return;

    const chunkSize = 10;
    for (var i = 0; i < symbols.length; i += chunkSize) {
      final chunk = symbols.sublist(i, math.min(i + chunkSize, symbols.length));

      for (final s in chunk) {
        await controller.addSymbol(s.options, s.data);
      }

      // Yield to the event loop
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  // Decode geometry
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

  mapbox.LatLng _tileOffsetToLatLng({
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

  mapbox.LatLng _tileXYToLatLng(double x, double y, int zoom) {
    final n = math.pi - (2.0 * math.pi * y) / math.pow(2.0, zoom.toDouble());
    final lat =
        (180.0 / math.pi) * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    final lng = x / math.pow(2.0, zoom.toDouble()) * 360.0 - 180.0;
    return mapbox.LatLng(lat, lng);
  }

  dynamic _parseVectorTileValue(VectorTileValue value) {
    if (value.stringValue != null) return value.stringValue;
    if (value.doubleValue != null) return value.doubleValue;
    if (value.intValue != null) return value.intValue;
    if (value.boolValue != null) return value.boolValue;
    return null;
  }

  // -------------------------------------------------------------
}
