import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reimbursement.dart';

/// Excepción de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Servicio encargado de toda la comunicación HTTP con la API
/// de reembolsos para el flujo del EMPLEADO.
class ReimbursementApiService {
  final http.Client _client = http.Client();

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  /// GET /api/reimbursements?employeeName=Empleado%20Demo
  Future<List<Reimbursement>> getMyReimbursements(String employeeName) async {
    final uri = Uri.parse(ApiConfig.baseUrl)
        .replace(queryParameters: {'employeeName': employeeName});
    try {
      final response =
          await _client.get(uri, headers: _headers).timeout(ApiConfig.timeout);
      return _handleListResponse(response);
    } on TimeoutException {
      throw const ApiException(
          'El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw const ApiException('No se pudo conectar con el servidor');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  /// POST /api/reimbursements
  Future<Reimbursement> createReimbursement({
    required String employeeName,
    required num amount,
    required String category,
    required String description,
  }) async {
    final uri = Uri.parse(ApiConfig.baseUrl);
    final body = jsonEncode(<String, dynamic>{
      'employeeName': employeeName,
      'amount': amount,
      'category': category,
      'description': description,
    });
    try {
      final response = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(ApiConfig.timeout);
      return _handleCreateResponse(response);
    } on TimeoutException {
      throw const ApiException(
          'El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw const ApiException('No se pudo conectar con el servidor');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor');
    }
  }

  List<Reimbursement> _handleListResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(Reimbursement.fromJson)
              .toList();
        }
        // Algunos backends envuelven la lista en un objeto.
        if (decoded is Map<String, dynamic>) {
          final items = decoded['items'] ?? decoded['data'];
          if (items is List) {
            return items
                .whereType<Map<String, dynamic>>()
                .map(Reimbursement.fromJson)
                .toList();
          }
        }
        throw const ApiException('Respuesta inesperada del servidor');
      case 404:
        // Empleado sin solicitudes según el backend.
        return <Reimbursement>[];
      default:
        throw ApiException(_errorMessage(response) ??
            'Error del servidor (código ${response.statusCode})');
    }
  }

  Reimbursement _handleCreateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return Reimbursement.fromJson(decoded);
      }
      throw const ApiException('Respuesta inesperada del servidor');
    }
    throw ApiException(_errorMessage(response) ??
        'No se pudo registrar la solicitud (código ${response.statusCode})');
  }

  /// Extrae el campo "message" del body de error {"message": "..."}.
  String? _errorMessage(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } on FormatException {
      // Body no JSON; usar el mensaje genérico.
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}
