import 'package:tap_map_app/presentation/widgets/theme_switcher.dart';
import 'package:tap_map_app/presentation/widgets/search_bar.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/material.dart';

class SearchBarAndButton extends StatelessWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final MapboxMapController? controller;

  const SearchBarAndButton({
    super.key,
    required this.onLocationSelected,
    required this.scaffoldKey,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
      children: [
        // -------------------------
        // MAP THEME SWITCHER (LEFT)
        // -------------------------
        Flexible(
          flex: 2,
          child: const MapThemeSwitcher(),
        ),
        const SizedBox(width: 8),

        // -------------------------
        // SEARCH AND RESULTS (RIGHT)
        // -------------------------
        Flexible(
          flex: 5,
          child: SearchBarAndResults(
            onLocationSelected: onLocationSelected,
            scaffoldKey: scaffoldKey,
            controller: controller, // Passed here
          ),
        ),
      ],
    );
  }
}