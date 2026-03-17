import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Converts a DioException to a user-friendly message.
String dioErrorToMessage(Object error) {
  if (error is! DioException) {
    return 'An unexpected error occurred. Please try again.';
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'Request timed out. Please check your connection.';
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return 'Session expired. Please log in again.';
      if (statusCode == 422) return 'Invalid request. Please check your inputs.';
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later.';
      }
      return 'Unexpected error. Please try again.';
    case DioExceptionType.cancel:
      return 'Request was cancelled.';
    default:
      return 'No connection. Please check your internet.';
  }
}

/// Shows a red floating snackbar with the given message.
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );
}

/// Shows a success snackbar.
void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );
}
