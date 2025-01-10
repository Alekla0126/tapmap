import 'package:tap_map_app/presentation/widgets/theme_switcher.dart';
import 'package:tap_map_app/presentation/widgets/search_bar.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

class SearchWithButton extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Function(Map<String, dynamic>) onLocationSelected;
  final MapBloc mapBloc;

  const SearchWithButton({
    Key? key,
    required this.scaffoldKey,
    required this.onLocationSelected,
    required this.mapBloc,
  }) : super(key: key);

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
          child: SearchBarAndResults(
            scaffoldKey: scaffoldKey,
            onLocationSelected: onLocationSelected,
            mapBloc: mapBloc,
          ),
        ),
      ],
    );
  }
}