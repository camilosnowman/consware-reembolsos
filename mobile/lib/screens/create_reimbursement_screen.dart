import 'package:flutter/material.dart';

import '../services/reimbursement_api_service.dart';

/// Pantalla con el formulario para registrar una nueva solicitud
/// de reembolso.
class CreateReimbursementScreen extends StatefulWidget {
  final ReimbursementApiService apiService;
  final String employeeName;
  /// Se llama después de registrar una solicitud con éxito
  /// (para, por ejemplo, cambiar a la pestaña de listado).
  final VoidCallback? onSuccess;

  const CreateReimbursementScreen({
    super.key,
    required this.apiService,
    required this.employeeName,
    this.onSuccess,
  });

  @override
  State<CreateReimbursementScreen> createState() =>
      _CreateReimbursementScreenState();
}

class _CreateReimbursementScreenState extends State<CreateReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'Alimentación';
  bool _submitting = false;

  static const List<String> _categories = <String>[
    'Alimentación',
    'Transporte',
    'Papelería',
    'Otros',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // No llamar a la API si el formulario no es válido.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.apiService.createReimbursement(
        employeeName: widget.employeeName,
        amount: num.tryParse(
                _amountController.text.replaceAll(',', '.').trim()) ??
            0,
        category: _category,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud registrada')),
      );
      _amountController.clear();
      _descriptionController.clear();
      setState(() => _category = 'Alimentación');
      widget.onSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      // Los valores del formulario se conservan para reintentar.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error inesperado. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nueva solicitud de reembolso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('Empleado: ${widget.employeeName}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto',
                hintText: 'Ej: 650000',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: !_submitting,
              validator: (value) {
                final parsed =
                    num.tryParse(value?.replaceAll(',', '.') ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Ingresa un monto mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe el gasto realizado',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 500,
              enabled: !_submitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa una descripción del gasto';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _submitting
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar solicitud'),
                  ),
          ],
        ),
      ),
    );
  }
}
