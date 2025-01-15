import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/constants/api_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class ForgotPasswordEvent extends AuthEvent {
  final String email;

  ForgotPasswordEvent({required this.email});

  @override
  List<Object> get props => [email];
}

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PasswordResetSuccess extends AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String authToken;

  AuthSuccess({required this.authToken});

  @override
  List<Object?> get props => [authToken];
}

class AuthFailure extends AuthState {
  final String error;

  AuthFailure({required this.error});

  @override
  List<Object?> get props => [error];
}

class CheckTokenEvent extends AuthEvent {}

class RegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String username;
  final String firstName;
  final String lastName;

  RegisterEvent({
    required this.email,
    required this.password,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  @override
  List<Object?> get props => [email, password, username, firstName, lastName];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  AuthBloc() : super(AuthInitial()) {
    on<ForgotPasswordEvent>(_onForgotPassword);
    on<CheckTokenEvent>(_onCheckToken);
    on<RegisterEvent>(_onRegister);
    on<LoginEvent>(_onLogin);
  }

  // Method to handle the registration event.
  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final url = Uri.parse(ApiConstants.register);
    final body = jsonEncode({
      "email": event.email,
      "password": event.password,
      "username": event.username,
      "first_name": event.firstName,
      "last_name": event.lastName,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      // Decode the response body.
      String decoded = utf8.decode(response.bodyBytes);
      debugPrint(decoded);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        emit(AuthSuccess(authToken: data["auth_token"] ?? ""));
      } else {
        final error = utf8.decode(response.bodyBytes);
        emit(AuthFailure(error: error));
      }
    } catch (e) {
      emit(AuthFailure(error: "An error occurred: ${e.toString()}"));
    }
  }

  // Method to handle the forgot password event.
  Future<void> _onForgotPassword(
      ForgotPasswordEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final url = Uri.parse(ApiConstants.forgotPassword);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': event.email}),
      );

      if (response.statusCode == 200) {
        emit(PasswordResetSuccess());
      } else {
        final responseBody = json.decode(response.body);
        emit(AuthFailure(error: responseBody['error'] ?? 'Unknown error'));
      }
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  // Method to check if a token exists in storage. It is necessary to check the token
  // or refresh it when the app is opened.
  Future<void> _onCheckToken(
      CheckTokenEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final token = await _storage.read(key: "auth_token");
      if (token != null) {
        emit(AuthSuccess(authToken: token));
      } else {
        emit(AuthInitial());
      }
    } catch (e) {
      emit(AuthFailure(error: "An error occurred. Please try again."));
    }
  }

  // Method to save the token in secure storage.
  void _saveToken(String token) async {
    final _storage = FlutterSecureStorage();
    await _storage.write(key: "auth_token", value: token);
  }

  // Method to login the user.
  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final url = Uri.parse(ApiConstants.login);
    final body = jsonEncode({
      "email": event.email,
      "password": event.password,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save the token in secure flutter storage.
        _saveToken(data["auth_token"]);
        emit(AuthSuccess(authToken: data["auth_token"]));
      } else {
        emit(AuthFailure(error: "Invalid email or password."));
      }
    } catch (e) {
      emit(AuthFailure(error: "An error occurred. Please try again."));
    }
  }
}
