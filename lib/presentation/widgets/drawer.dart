import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

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

  // -------------------------------------
  // Helper method to launch URLs
  // -------------------------------------
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  // -------------------------------------
  // Helper method to make phone calls
  // -------------------------------------
  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint("Could not launch phone call to $phoneNumber");
    }
  }

  // -------------------------------------
  // Helper method to format working hours
  // -------------------------------------
  String _formatWorkingHours(Map<String, dynamic> workingHours) {
    List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    String formattedHours = '';
    for (String day in days) {
      String dayKey = day.toLowerCase();
      bool isClosed = workingHours['is_${dayKey}_closed'] ?? false;
      bool is24Hours = workingHours['is_${dayKey}_24_hours'] ?? false;
      List<dynamic> openTimes = workingHours['${dayKey}_open_times'] ?? [];
      List<dynamic> closeTimes = workingHours['${dayKey}_close_times'] ?? [];

      formattedHours += '$day: ';
      if (isClosed) {
        formattedHours += 'Closed\n';
      } else if (is24Hours) {
        formattedHours += 'Open 24 Hours\n';
      } else {
        List<String> periods = [];
        for (int i = 0; i < openTimes.length; i++) {
          String open = openTimes[i];
          String close = closeTimes.length > i ? closeTimes[i] : '';
          periods.add('${open.substring(0, 5)} - ${close.substring(0, 5)}');
        }
        formattedHours += '${periods.join(', ')}\n';
      }
    }
    return formattedHours;
  }

  // -------------------------------------
  // Method to scroll up
  // -------------------------------------
  void _scrollUp() {
    _scrollController.animateTo(
      _scrollController.offset - 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // -------------------------------------
  // Method to scroll down
  // -------------------------------------
  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.offset + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------
  // Build Methods for UI Sections
  // -------------------------------------

  // 1. Name Section
  Widget _buildNameSection(Map<String, dynamic> properties) {
    return Text(
      properties['name'] ?? 'Unnamed',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 2. Address Section
  Widget _buildAddressSection(Map<String, dynamic> properties) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            properties['address'] ?? 'No Address',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  // 3. Description Section
  Widget _buildDescriptionSection(Map<String, dynamic> properties) {
    return Text(
      properties['description'] ?? 'No Description',
      style: const TextStyle(fontSize: 14),
    );
  }

  // 4. Contact Information Section
  Widget _buildContactInfoSection(Map<String, dynamic> properties) {
    final contactInfo = properties['contact_info'];
    if (contactInfo == null) return const SizedBox.shrink();

    return Column(
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
        if ((contactInfo['phone_numbers'] ?? []).isNotEmpty)
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
        if ((contactInfo['emails'] ?? []).isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.from(
              (contactInfo['emails'] as List).map<Widget>((email) => ListTile(
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
        if ((contactInfo['websites'] ?? []).isNotEmpty)
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
        // Tripadvisor Links
        if ((contactInfo['tripadvisor_urls'] ?? []).isNotEmpty)
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
    );
  }

  // 5. Working Hours Section
  Widget _buildWorkingHoursSection(Map<String, dynamic> properties) {
    if (properties['working_hours'] == null) return const SizedBox.shrink();

    return Column(
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
          _formatWorkingHours(properties['working_hours']),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  // 6. Action Buttons (Call, Website, Directions)
  Widget _buildActionButtons(Map<String, dynamic> properties, Map geometry) {
    final contactInfo = properties['contact_info'];

    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: [
        // Call Button
        if ((contactInfo['phone_numbers'] ?? []).isNotEmpty)
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
        if ((contactInfo['websites'] ?? []).isNotEmpty)
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
            final coords = geometry['coordinates'];
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
    );
  }

  // 7. Additional Information (Tags)
  Widget _buildAdditionalInformation(Map<String, dynamic> properties) {
    if ((properties['tags'] ?? []).isEmpty) return const SizedBox.shrink();

    return Column(
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
            (properties['tags'] as List).map<Widget>((tag) => Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue,
                )),
          ),
        ),
      ],
    );
  }

  // 8. Scroll Buttons
  Widget _buildScrollButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _scrollUp,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Icon(Icons.arrow_upward, color: Colors.white),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _scrollDown,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Icon(Icons.arrow_downward, color: Colors.white),
        ),
      ],
    );
  }

  // -------------------------------------
  // Main Build Method
  // -------------------------------------
  @override
  Widget build(BuildContext context) {
    if (widget.drawerDetails == null) {
      return const Drawer(
        child: Center(child: Text('No details')),
      );
    }

    final properties = widget.drawerDetails!['properties'] ?? {};
    final geometry = widget.drawerDetails!['geometry'] ?? {};

    return Drawer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
        child: Column(
          children: [
            // Content Area with ScrollController
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameSection(properties),
                    const SizedBox(height: 10),
                    _buildAddressSection(properties),
                    const SizedBox(height: 10),
                    _buildDescriptionSection(properties),
                    const SizedBox(height: 20),
                    _buildContactInfoSection(properties),
                    const SizedBox(height: 20),
                    _buildWorkingHoursSection(properties),
                    const SizedBox(height: 20),
                    _buildActionButtons(properties, geometry),
                    const SizedBox(height: 20),
                    _buildAdditionalInformation(properties),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildScrollButtons(),
          ],
        ),
      ),
    );
  }
}
