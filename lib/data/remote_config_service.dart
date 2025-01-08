import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  Future<String> getAccessToken() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(days: 1),
      ));

      await remoteConfig.fetchAndActivate();
      return remoteConfig.getString('mapbox_access_token');
    } catch (e) {
      throw Exception("Failed to fetch Remote Config: $e");
    }
  }
}
