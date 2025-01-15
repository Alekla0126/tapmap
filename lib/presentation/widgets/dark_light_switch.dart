import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

AppBar buildAppBar(String title) {
  return AppBar(
    title: Text(title),
    actions: [
      BlocBuilder<MapBloc, MapState>(
        builder: (context, state) {
          return IconButton(
            icon: Icon(
              state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () {
              context.read<MapBloc>().toggleTheme();
            },
          );
        },
      ),
    ],
  );
}