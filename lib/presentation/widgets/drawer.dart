import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/blocs/map_bloc.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        final styles = state.availableStyles;
        return Drawer(
          child: Column(
            children: [
              const DrawerHeader(
                child: Text(
                  "Choose a Style",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (styles.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("No styles available"),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: styles.length,
                    itemBuilder: (context, index) {
                      final style = styles[index];
                      return ListTile(
                        title: Text(style['name']!),
                        onTap: () {
                          context
                              .read<MapBloc>()
                              .updateStyle(style['style_url']!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
