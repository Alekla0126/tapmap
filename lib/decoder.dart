import 'package:vector_tile/vector_tile.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class VectorTileManager {
  static const String TILE_URL =
      'https://map-travel.net/tilesets/data/tiles/0/0/0.pbf';
  List<Map<String, dynamic>> _features = [];

  dynamic _parseVectorTileValue(VectorTileValue value) {
    if (value.stringValue != null) return value.stringValue;
    if (value.doubleValue != null) return value.doubleValue;
    if (value.intValue != null) return value.intValue;
    if (value.boolValue != null) return value.boolValue;
    return null;
  }

  List<double> _parseGeometry(Geometry geometry) {
    // Access raw geometry data
    if (geometry.type == VectorTileGeomType.POINT) {

      // Print for debugging
      print('Raw geometry: $geometry');

      // Try to extract coordinates
      // if (geometry >= 2) {
      //   return [rawGeometry[0].toDouble(), rawGeometry[1].toDouble()];
      // }
    }
    return [];
  }

  Future<void> loadTile() async {
    try {
      final response = await http.get(Uri.parse(TILE_URL));
      final vectorTile = VectorTile.fromBytes(bytes: response.bodyBytes);

      _features = vectorTile.layers
          .expand((layer) => layer.features.map((feature) => {
                'layerName': layer.name,
                'geometry': {
                  'type': feature.type.toString(),
                  'coordinates': feature.geometryList,
                },
                'properties': {
                  for (int i = 0; i < feature.tags.length; i += 2)
                    layer.keys[feature.tags[i]]:
                        _parseVectorTileValue(layer.values[feature.tags[i + 1]])
                },
              }))
          .toList();

      print('Loaded ${_features.length} features');
    } catch (e) {
      print('Error loading tile: $e');
    }
  }

  List<Map<String, dynamic>> get features => _features;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tileManager = VectorTileManager();
  await tileManager.loadTile();

  runApp(MyApp(tileManager: tileManager));
}

class MyApp extends StatelessWidget {
  final VectorTileManager tileManager;

  const MyApp({Key? key, required this.tileManager}) : super(key: key);

  String formatProperties(Map<String, dynamic> properties) {
    return properties.entries.map((e) => '    ${e.key}: ${e.value}').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Loaded ${tileManager.features.length} features'),
              ...tileManager.features
                  .map((feature) => Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '''
Layer: ${feature['layerName']}
Geometry: ${feature['geometry']}
Properties:
${formatProperties(feature['properties'])}
''',
                          style: TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }
}
