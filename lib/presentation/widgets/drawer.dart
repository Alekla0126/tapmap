import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic>? drawerDetails;

  const CustomDrawer({
    Key? key,
    this.drawerDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: drawerDetails == null
          ? const Center(child: Text('No details'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drawerDetails!['properties']['name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      drawerDetails!['properties']['address'] ?? 'No Address',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      drawerDetails!['properties']['description'] ??
                          'No Description',
                      style: const TextStyle(fontSize: 14),
                    ),
                    // ... more details if needed
                  ],
                ),
              ),
            ),
    );
  }
}