import 'package:tap_map_app/presentation/widgets/theme_switcher.dart';
import 'package:tap_map_app/presentation/widgets/search_bar.dart';
import 'package:flutter/material.dart';

class SearchWithButton extends StatelessWidget {
  const SearchWithButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
      children: [
        // -------------------------
        // MAP CONTROLLER (LEFT)
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
          child: const SearchBarAndResults(),
        ),
      ],
    );
  }
}