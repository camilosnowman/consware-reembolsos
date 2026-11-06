/// Configuración de la API.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Emulador Android: 10.0.2.2 apunta al host (localhost del PC).
  /// Web (Chrome) para pruebas locales: localhost directo.
  /// Dispositivo físico real: reemplazar por la IP LAN del PC.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api/reimbursements';
    return 'http://10.0.2.2:5000/api/reimbursements';
  }

  /// Timeout general para todas las peticiones HTTP.
  static const Duration timeout = Duration(seconds: 10);
}
