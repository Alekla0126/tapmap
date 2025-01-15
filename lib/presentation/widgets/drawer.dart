import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic>? drawerDetails;

  const CustomDrawer({
    Key? key,
    this.drawerDetails,
  }) : super(key: key);

  // Helper method to launch URLs
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Could not launch the URL
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
    for (int i = 0; i < days.length; i++) {
      String day = days[i].toLowerCase();
      bool isClosed = workingHours['is_${day}_closed'] ?? false;
      bool is24Hours = workingHours['is_${day}_24_hours'] ?? false;
      List<dynamic> openTimes = workingHours['${day}_open_times'] ?? [];
      List<dynamic> closeTimes = workingHours['${day}_close_times'] ?? [];

      formattedHours += '${days[i]}: ';
      if (isClosed) {
        formattedHours += 'Closed\n';
      } else if (is24Hours) {
        formattedHours += 'Open 24 Hours\n';
      } else {
        List<String> periods = [];
        for (int j = 0; j < openTimes.length; j++) {
          String open = openTimes[j];
          String close = closeTimes.length > j ? closeTimes[j] : '';
          periods.add('${open.substring(0, 5)} - ${close.substring(0, 5)}');
        }
        formattedHours += '${periods.join(', ')}\n';
      }
    }
    return formattedHours;
  }

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
                    // Place Name
                    Text(
                      drawerDetails!['properties']['name'] ?? 'Unnamed',
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
                            drawerDetails!['properties']['address'] ??
                                'No Address',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Text(
                      drawerDetails!['properties']['description'] ??
                          'No Description',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // Contact Information
                    if (drawerDetails!['properties']['contact_info'] != null)
                      Column(
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
                          if (drawerDetails!['properties']['contact_info']
                                  ['phone_numbers'] !=
                              null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.from(
                                (drawerDetails!['properties']['contact_info']
                                        ['phone_numbers'] ??
                                    [])
                                    .map<Widget>((phone) => ListTile(
                                          leading: const Icon(Icons.phone),
                                          title: Text(phone),
                                          onTap: () => _makePhoneCall(phone),
                                        )),
                              ),
                            ),
                          // Emails
                          if (drawerDetails!['properties']['contact_info']
                                  ['emails'] !=
                              null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.from(
                                (drawerDetails!['properties']['contact_info']
                                        ['emails'] ??
                                    [])
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
                          if (drawerDetails!['properties']['contact_info']
                                  ['websites'] !=
                              null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.from(
                                (drawerDetails!['properties']['contact_info']
                                        ['websites'] ??
                                    [])
                                    .map<Widget>((website) => ListTile(
                                          leading:
                                              const Icon(Icons.language),
                                          title: Text(website),
                                          onTap: () => _launchURL(website),
                                        )),
                              ),
                            ),
                          // Social Media Links (e.g., Tripadvisor)
                          if (drawerDetails!['properties']['contact_info']
                                  ['tripadvisor_urls'] !=
                              null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.from(
                                (drawerDetails!['properties']['contact_info']
                                        ['tripadvisor_urls'] ??
                                    [])
                                    .map<Widget>((url) => ListTile(
                                          leading: const Icon(Icons.star,
                                              color: Colors.orange),
                                          title: const Text('TripAdvisor'),
                                          onTap: () => _launchURL(url),
                                        )),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Working Hours
                    if (drawerDetails!['properties']['working_hours'] != null)
                      Column(
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
                            _formatWorkingHours(
                                drawerDetails!['properties']['working_hours']),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Call Button
                        if (drawerDetails!['properties']['contact_info']
                                ['phone_numbers'] !=
                            null)
                          ElevatedButton.icon(
                            onPressed: () {
                              final phones = drawerDetails!['properties']
                                      ['contact_info']['phone_numbers'] ??
                                  [];
                              if (phones.isNotEmpty) {
                                _makePhoneCall(phones[0]);
                              }
                            },
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        // Website Button
                        if (drawerDetails!['properties']['contact_info']
                                ['websites'] !=
                            null)
                          ElevatedButton.icon(
                            onPressed: () {
                              final websites = drawerDetails!['properties']
                                      ['contact_info']['websites'] ??
                                  [];
                              if (websites.isNotEmpty) {
                                _launchURL(websites[0]);
                              }
                            },
                            icon: const Icon(Icons.language),
                            label: const Text('Website'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        // Directions Button
                        ElevatedButton.icon(
                          onPressed: () {
                            final coords = drawerDetails!['geometry']['coordinates'];
                            if (coords != null && coords.length >= 2) {
                              final lat = coords[1];
                              final lng = coords[0];
                              final googleMapsUrl =
                                  'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                              _launchURL(googleMapsUrl);
                            }
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Additional Information (e.g., Tags)
                    if (drawerDetails!['properties']['tags'] != null &&
                        (drawerDetails!['properties']['tags'] as List).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          ),
                          const Divider(color: Colors.white),
                          SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List<Widget>.from(
                            (drawerDetails!['properties']['tags'] as List)
                              .map<Widget>((tag) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Chip(
                                  label: Text(tag),
                                  ),
                                )),
                            ),
                          ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}