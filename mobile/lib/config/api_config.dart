/// Configuración de la API.
class ApiConfig {
  /// 10.0.2.2 es la IP especial del emulador de Android que apunta al
  /// localhost (127.0.0.1) de la máquina donde corre el backend.
  static const String baseUrl = 'http://10.0.2.2:5000/api/reimbursements';

  // NOTA: en un dispositivo físico real, reemplazar por la IP LAN del PC,
  // por ejemplo: 'http://192.168.1.50:5000/api/reimbursements'

  /// Timeout general para todas las peticiones HTTP.
  static const Duration timeout = Duration(seconds: 10);
}
