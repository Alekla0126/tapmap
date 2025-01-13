// MapWidget.dart

import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MapWidget extends StatefulWidget {
  final String accessToken;
  final String styleString;
  final CameraPosition initialCameraPosition;
  final Future<void> Function(MapboxMapController controller) onMapCreated;
  final VoidCallback onCameraIdle;
  final Map<String, Map<String, dynamic>> featureProperties;
  final Function(Symbol symbol) handleMarkerClick;

  const MapWidget({
    Key? key,
    required this.accessToken,
    required this.styleString,
    required this.initialCameraPosition,
    required this.onMapCreated,
    required this.onCameraIdle,
    required this.featureProperties,
    required this.handleMarkerClick,
  }) : super(key: key);

  @override
  MapWidgetState createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  MapboxMapController? controller;

  @override
  Widget build(BuildContext context) {
    return MapboxMap(
      accessToken: widget.accessToken,
      styleString: widget.styleString,
      initialCameraPosition: widget.initialCameraPosition,
      onMapCreated: (MapboxMapController mapController) async {
        controller = mapController;
        await widget.onMapCreated(mapController);

        // Set up marker click handler
        controller!.onSymbolTapped.add((Symbol symbol) {
          widget.handleMarkerClick(symbol);
        });
      },
      onStyleLoadedCallback: () {
        // Additional style loaded actions can be handled here if needed
      },
      onCameraIdle: widget.onCameraIdle,
      trackCameraPosition: true,
      gestureRecognizers: Set()
        ..add(Factory<OneSequenceGestureRecognizer>(
            () => EagerGestureRecognizer())), // Allow all gestures
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
