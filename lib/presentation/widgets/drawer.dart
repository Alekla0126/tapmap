import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // Import from dart:ui instead of dart:ui_web

class CustomDrawer extends StatefulWidget {
  final Map<String, dynamic>? drawerDetails;

  const CustomDrawer({
    super.key,
    this.drawerDetails,
  });

  @override
  CustomDrawerState createState() => CustomDrawerState();
}

class CustomDrawerState extends State<CustomDrawer> {
  final ScrollController _scrollController = ScrollController();

  // Helper method to launch URLs
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  // Helper method to make phone calls
  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint("Could not launch phone call to $phoneNumber");
    }
  }

  // Helper method to format working hours
  String _formatWorkingHours(Map<String, dynamic> workingHours) {
    final List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    String formattedHours = '';
    for (int i = 0; i < days.length; i++) {
      final day = days[i].toLowerCase();
      final isClosed = workingHours['is_${day}_closed'] ?? false;
      final is24Hours = workingHours['is_${day}_24_hours'] ?? false;
      final openTimes = workingHours['${day}_open_times'] ?? [];
      final closeTimes = workingHours['${day}_close_times'] ?? [];

      formattedHours += '${days[i]}: ';
      if (isClosed) {
        formattedHours += 'Closed\n';
      } else if (is24Hours) {
        formattedHours += 'Open 24 Hours\n';
      } else {
        final periods = <String>[];
        for (int j = 0; j < openTimes.length; j++) {
          final open = openTimes[j];
          final close = (closeTimes.length > j) ? closeTimes[j] : '';
          periods.add('${open.substring(0, 5)} - ${close.substring(0, 5)}');
        }
        formattedHours += '${periods.join(', ')}\n';
      }
    }
    return formattedHours;
  }

  // Method to scroll up
  void _scrollUp() {
    double newOffset = _scrollController.offset - 100;
    if (newOffset < 0) newOffset = 0;
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Method to scroll down
  void _scrollDown() {
    double maxOffset = _scrollController.position.maxScrollExtent;
    double newOffset = _scrollController.offset + 100;
    if (newOffset > maxOffset) newOffset = maxOffset;
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: widget.drawerDetails == null
          ? const Center(child: Text('No details'))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Content Area with ScrollController
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Place Name
                              Text(
                                widget.drawerDetails!['properties']['name'] ?? 'Unnamed',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Address
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.drawerDetails!['properties']['address'] ?? 'No Address',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Description
                              Text(
                                widget.drawerDetails!['properties']['description'] ?? 'No Description',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 20),

                              // Contact Information
                              if (widget.drawerDetails!['properties']['contact_info'] != null)
                                _buildContactInfo(),
                              // Working Hours
                              if (widget.drawerDetails!['properties']['working_hours'] != null)
                                _buildWorkingHours(),

                              // Action Buttons
                              _buildActionButtons(),

                              // Tags
                              if (widget.drawerDetails!['properties']['tags'] != null &&
                                  (widget.drawerDetails!['properties']['tags'] as List).isNotEmpty)
                                _buildTagsSection(),
                              // Add some spacing
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    bottom: 20,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          onPressed: _scrollUp,
                          backgroundColor: Colors.red,
                          child: const Icon(Icons.arrow_upward, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton(
                          onPressed: _scrollDown,
                          backgroundColor: Colors.blue,
                          child: const Icon(Icons.arrow_downward, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactInfo() {
    final contactInfo = widget.drawerDetails!['properties']['contact_info'] ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          // Phone Numbers
          if ((contactInfo['phone_numbers'] as List?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.from(
                (contactInfo['phone_numbers'] as List)
                    .map<Widget>((phone) => ListTile(
                          leading: const Icon(Icons.phone),
                          title: Text(phone),
                          onTap: () => _makePhoneCall(phone),
                        )),
              ),
            ),
          // Emails
          if ((contactInfo['emails'] as List?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.from(
                (contactInfo['emails'] as List)
                    .map<Widget>((email) => ListTile(
                          leading: const Icon(Icons.email),
                          title: Text(email),
                          onTap: () {
                            // Implement email launch if needed
                            // _launchURL('mailto:$email');
                          },
                        )),
              ),
            ),
          // Websites
          if ((contactInfo['websites'] as List?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.from(
                (contactInfo['websites'] as List)
                    .map<Widget>((website) => ListTile(
                          leading: const Icon(Icons.language),
                          title: Text(website),
                          onTap: () => _launchURL(website),
                        )),
              ),
            ),
          // Social Media Links (e.g., Tripadvisor)
          if ((contactInfo['tripadvisor_urls'] as List?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.from(
                (contactInfo['tripadvisor_urls'] as List)
                    .map<Widget>((url) => ListTile(
                          leading: const Icon(Icons.star, color: Colors.orange),
                          title: const Text('TripAdvisor'),
                          onTap: () => _launchURL(url),
                        )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkingHours() {
    final workingHours = widget.drawerDetails!['properties']['working_hours'] ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Working Hours',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          Text(
            _formatWorkingHours(workingHours),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final contactInfo = widget.drawerDetails!['properties']['contact_info'] ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Wrap(
        spacing: 10.0,
        runSpacing: 10.0,
        children: [
          // Call Button
          if ((contactInfo['phone_numbers'] as List?)?.isNotEmpty ?? false)
            ElevatedButton.icon(
              onPressed: () {
                final phones = contactInfo['phone_numbers'] as List;
                if (phones.isNotEmpty) {
                  _makePhoneCall(phones[0]);
                }
              },
              icon: const Icon(Icons.call, color: Colors.white),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white, // Text color
              ),
            ),

          // Website Button
          if ((contactInfo['websites'] as List?)?.isNotEmpty ?? false)
            ElevatedButton.icon(
              onPressed: () {
                final websites = contactInfo['websites'] as List;
                if (websites.isNotEmpty) {
                  _launchURL(websites[0]);
                }
              },
              icon: const Icon(Icons.language, color: Colors.white),
              label: const Text('Website'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white, // Text color
              ),
            ),

          // Directions Button
          ElevatedButton.icon(
            onPressed: () {
              final coords = widget.drawerDetails!['geometry']['coordinates'];
              if (coords != null && coords.length >= 2) {
                final lat = coords[1];
                final lng = coords[0];
                final googleMapsUrl =
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                _launchURL(googleMapsUrl);
              }
            },
            icon: const Icon(Icons.directions, color: Colors.white),
            label: const Text('Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white, // Text color
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    final tags = widget.drawerDetails!['properties']['tags'] as List? ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tags',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: List<Widget>.from(
              tags.map<Widget>((tag) => Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blue,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}