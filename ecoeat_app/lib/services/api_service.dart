import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/receta.dart';

/// Excepción con mensaje legible para mostrar en un SnackBar.
class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Cliente HTTP hacia el backend Flask.
class ApiService {
  /// Android emulator: 10.0.2.2 apunta al localhost del PC.
  /// Celular físico: usar la IP local del PC (ej. http://192.168.1.10:5000).
  /// Web/escritorio: localhost.
  static String baseUrl =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:5000'
          : 'http://localhost:5000';

  static const _headers = {'Content-Type': 'application/json'};

  /// GET /api/ingredientes/sugeridos
  static Future<List<String>> obtenerSugeridos() async {
    final data = await _send(
      () => http.get(Uri.parse('$baseUrl/api/ingredientes/sugeridos')),
      timeout: const Duration(seconds: 10),
    );
    final lista = data['ingredientes'];
    if (lista is! List) throw ApiException('Formato de sugerencias inválido');
    return lista.map((e) => e.toString()).toList();
  }

  /// POST /api/receta/generar
  static Future<Receta> generarReceta(List<String> ingredientes) async {
    final data = await _send(
      () => http.post(
        Uri.parse('$baseUrl/api/receta/generar'),
        headers: _headers,
        body: jsonEncode({'ingredientes': ingredientes}),
      ),
      timeout: const Duration(seconds: 90),
    );
    final receta = data['receta'];
    if (receta is! Map<String, dynamic>) {
      throw ApiException('La respuesta no contiene una receta');
    }
    return Receta.fromJson(receta);
  }

  static Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    required Duration timeout,
  }) async {
    try {
      final resp = await request().timeout(timeout);
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException('Respuesta no válida del servidor (${resp.statusCode})');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ApiException(data['error']?.toString() ?? 'Error ${resp.statusCode}');
      }
      return data;
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder');
    } on http.ClientException {
      throw ApiException('No se pudo conectar a $baseUrl');
    }
  }
}
