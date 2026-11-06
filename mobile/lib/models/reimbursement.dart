/// Modelo de dominio de una solicitud de reembolso.
class Reimbursement {
  final int id;
  final String employeeName;
  final num amount;
  final String category;
  final String description;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAtUtc;
  final DateTime? decidedAtUtc;

  const Reimbursement({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
    required this.status,
    this.rejectionReason,
    this.createdAtUtc,
    this.decidedAtUtc,
  });

  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      if (value == null || value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toUtc();
    }

    return Reimbursement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeName: (json['employeeName'] as String?) ?? '',
      amount: (json['amount'] as num?) ?? 0,
      category: (json['category'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Pendiente',
      rejectionReason: json['rejectionReason'] as String?,
      createdAtUtc: parseDate(json['createdAtUtc']),
      decidedAtUtc: parseDate(json['decidedAtUtc']),
    );
  }
}
