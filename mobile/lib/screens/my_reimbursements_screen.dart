import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../widgets/status_badge.dart';

/// Pantalla que lista las solicitudes de reembolso del empleado.
class MyReimbursementsScreen extends StatefulWidget {
  final ReimbursementApiService apiService;
  final String employeeName;

  /// Se incrementa desde HomeShell cada vez que se entra a esta pestaña
  /// (p. ej. tras crear una solicitud con POST) para repetir el GET
  /// automáticamente. Con IndexedStack el initState ocurre una sola vez,
  /// así que el refresco se notifica con este contador vía didUpdateWidget.
  final int refreshVersion;

  const MyReimbursementsScreen({
    super.key,
    required this.apiService,
    required this.employeeName,
    this.refreshVersion = 0,
  });

  @override
  State<MyReimbursementsScreen> createState() =>
      _MyReimbursementsScreenState();
}

class _MyReimbursementsScreenState extends State<MyReimbursementsScreen> {
  /// Separador de miles es-CO para el monto (650000 → 650.000).
  static final NumberFormat _thousands = NumberFormat.decimalPattern('es_CO');
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');

  List<Reimbursement> _items = <Reimbursement>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(MyReimbursementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nueva entrada a la pestaña (o POST exitoso que cambia a ella):
    // repetir el GET sin perder el estado de la pantalla.
    if (widget.refreshVersion != oldWidget.refreshVersion) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.apiService.getMyReimbursements(
        widget.employeeName,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _loading = false;
      });
    }
  }

  String _formatAmount(Reimbursement r) {
    // "$650.000 COP" según formato de Colombia.
    return '\$${_thousands.format(r.amount)} COP';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
              ),
            ],
          ),
        ),
      );
    }
    // Tanto la lista vacía como la corta siguen siendo deslizables para
    // que "tirar para refrescar" siempre esté disponible.
    return RefreshIndicator(
      onRefresh: _fetch,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
              children: const [
                Icon(Icons.receipt_long, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Aún no tienes solicitudes',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final r = _items[index];
                final isRejected = isRejectedStatus(r.status);
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r.category,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            StatusBadge(status: r.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatAmount(r),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (r.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(r.description),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          r.createdAtUtc != null
                              ? 'Enviada: ${_dateFmt.format(r.createdAtUtc!.toLocal())}'
                              : 'Fecha no disponible',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (isRejected && r.rejectionReason != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Motivo del rechazo: ${r.rejectionReason}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
