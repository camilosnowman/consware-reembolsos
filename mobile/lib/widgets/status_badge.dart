import 'package:flutter/material.dart';

/// Etiqueta en español para el estado que envía la API
/// (inglés: Pending/Approved/Rejected). Acepta también español.
String statusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
    case 'aprobada':
      return 'Aprobada';
    case 'rejected':
    case 'rechazada':
      return 'Rechazada';
    case 'pending':
    case 'pendiente':
    default:
      return 'Pendiente';
  }
}

/// Color asociado al estado (inglés de la API o español).
Color statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'approved':
    case 'aprobada':
      return Colors.green.shade700;
    case 'rejected':
    case 'rechazada':
      return Colors.red.shade700;
    case 'pending':
    case 'pendiente':
    default:
      return Colors.orange.shade800;
  }
}

/// true si el estado corresponde a una solicitud rechazada.
/// La API envía "Rejected"; se acepta también "rechazada".
bool isRejectedStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'rejected' || normalized == 'rechazada';
}

/// Insignia (badge) que muestra el estado de una solicitud con su color.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
