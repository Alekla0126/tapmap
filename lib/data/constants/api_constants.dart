import 'environment.dart';

class ApiConstants {
  // Endpoints
  static const String featureCollection = '${Environment.baseUrl}/feature/collection/';
  static const String forgotPassword = '${Environment.baseUrl}/users/reset_password/';
  static const String login = '${Environment.baseUrl}/auth/token/login/';
  static const String register = '${Environment.baseUrl}/users/';
  static const String styles = '${Environment.baseUrl}/styles/';
}
