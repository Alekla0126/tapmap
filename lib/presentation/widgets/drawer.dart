import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Map<String, dynamic>? drawerDetails;

  const CustomDrawer({
    super.key,
    this.drawerDetails,
  });

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use FittedBox with BoxFit.scaleDown so the child is only scaled
          // down if it doesn’t fit. (It won’t scale up if smaller.)
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            // We use a ConstrainedBox that only fixes the width
            // (so the child can measure its "natural" height).
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Force the child to use the full drawer width
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                // Do *not* constrain height, so the child can grow
                // and FittedBox can figure out how much to shrink if necessary.
              ),
              child: _buildDrawerContent(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerContent(BuildContext context) {
    // You might add some padding or margin here if needed.
    // But be mindful that any extra padding also takes vertical space
    // and thus might cause more scaling.
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: drawerDetails == null
          ? const Center(
              child: Text(
                'No details',
                // If you worry about text getting too small,
                // you can specify smaller fonts or use something
                // like AutoSizeText for just the text widgets.
                style: TextStyle(fontSize: 24),
              ),
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max, // Let the column wrap its content
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
                drawerDetails!['properties']['address'] ?? 'No Address',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Description
        Text(
          drawerDetails!['properties']['description'] ?? 'No Description',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 20),
        // Contact Information
        if (drawerDetails!['properties']['contact_info'] != null)
          _buildContactInfo(),
        // Working Hours
        if (drawerDetails!['properties']['working_hours'] != null)
          _buildWorkingHours(),

        // Action Buttons (no horizontal scroll)
        _buildActionButtons(),

        // Tags
        if (drawerDetails!['properties']['tags'] != null &&
            (drawerDetails!['properties']['tags'] as List).isNotEmpty)
          _buildTagsSection(),
        // Add the SizedBox at the end
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildContactInfo() {
    final contactInfo = drawerDetails!['properties']['contact_info'];
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
        if (contactInfo['phone_numbers'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.from(
              (contactInfo['phone_numbers'] ?? []).map<Widget>((phone) {
                return ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(phone),
                  onTap: () => _makePhoneCall(phone),
                );
              }),
            ),
          ),
        // Emails
        if (contactInfo['emails'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.from(
              (contactInfo['emails'] ?? []).map<Widget>((email) {
                return ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(email),
                  onTap: () {
                    // Implement email launch if needed
                    // launchUrl(Uri.parse('mailto:$email'));
                  },
                );
              }),
            ),
          ),
        // Websites
        if (contactInfo['websites'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.from(
              (contactInfo['websites'] ?? []).map<Widget>((website) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(website),
                  onTap: () => _launchURL(website),
                );
              }),
            ),
          ),
        // Social Media Links
        if (contactInfo['tripadvisor_urls'] != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List<Widget>.from(
              (contactInfo['tripadvisor_urls'] ?? []).map<Widget>((url) {
                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.orange),
                  title: const Text('TripAdvisor'),
                  onTap: () => _launchURL(url),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkingHours() {
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
          _formatWorkingHours(drawerDetails!['properties']['working_hours']),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final contactInfo = drawerDetails!['properties']['contact_info'];
    final phones = contactInfo['phone_numbers'] ?? [];
    final websites = contactInfo['websites'] ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallWidth = constraints.maxWidth < 300;
        return Padding(
          padding: const EdgeInsets.only(top: 0),
          child: isSmallWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildButtons(phones, websites, isSmallWidth)
                      .expand((button) => [button, const SizedBox(height: 10)])
                      .toList()
                      ..removeLast(), // Remove the last SizedBox
                )
              : Row(
                  children: _buildButtons(phones, websites, isSmallWidth),
                ),
        );
      },
    );
  }

  List<Widget> _buildButtons(List phones, List websites, bool isSmallWidth) {
    final buttonStyle = ElevatedButton.styleFrom(
      textStyle: TextStyle(fontSize: isSmallWidth ? 12 : 16),
      padding: EdgeInsets.symmetric(
        vertical: isSmallWidth ? 8 : 12,
        horizontal: isSmallWidth ? 12 : 16,
      ),
    );

    return [
      // Call Button
      if (phones.isNotEmpty)
        ElevatedButton.icon(
          onPressed: () => _makePhoneCall(phones[0]),
          icon: const Icon(Icons.call, color: Colors.white),
          label: const Text('Call'),
          style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(Colors.blue),
            foregroundColor: MaterialStateProperty.all(Colors.white),
          ),
        ),
      if (!isSmallWidth) const SizedBox(width: 10),

      // Website Button
      if (websites.isNotEmpty)
        ElevatedButton.icon(
          onPressed: () => _launchURL(websites[0]),
          icon: const Icon(Icons.language, color: Colors.white),
          label: const Text('Website'),
          style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(Colors.green),
            foregroundColor: MaterialStateProperty.all(Colors.white),
          ),
        ),
      if (!isSmallWidth) const SizedBox(width: 10),

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
        icon: const Icon(Icons.directions, color: Colors.white),
        label: const Text('Directions'),
        style: buttonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.red),
          foregroundColor: MaterialStateProperty.all(Colors.white),
        ),
      ),
    ];
  }

  Widget _buildTagsSection() {
    final List tags = drawerDetails!['properties']['tags'];
    return Padding(
      padding: const EdgeInsets.only(top: 20),
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
            spacing: 12.0,
            runSpacing: 8.0,
            children: tags.map<Widget>((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.blue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
