import 'package:vector_tile/vector_tile.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

class VectorTileDownloader {
  final int zoom;
  final int x;
  final int y;

  VectorTileDownloader(this.zoom, this.x, this.y);

  Future<void> downloadAndDecodeTile() async {
    final String tileUrl = "https://map-travel.net/tilesets/data/tiles/$zoom/$x/$y.pbf";
    final response = await http.get(Uri.parse(tileUrl));

    if (response.statusCode == 200) {
      print("Tile downloaded successfully.");
      final tileData = response.bodyBytes;

      // Decode the vector tile
      final tile = await VectorTile.fromBytes(bytes: tileData);
      for (var layer in tile.layers) {
        print("Layer: ${layer.name}");
        for (var feature in layer.features) {
          print("Feature ID: ${feature.properties}");
        }
      }
    } else {
      print("Failed to download the tile.");
    }
  }
}
