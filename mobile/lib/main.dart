import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'screens/create_reimbursement_screen.dart';
import 'screens/my_reimbursements_screen.dart';
import 'services/reimbursement_api_service.dart';

/// Nombre del empleado autenticado. En una app real vendría de un login.
const String kEmployeeName = 'Empleado Demo';

Future<void> main() async {
  // Carga los patrones de números/fechas del locale es_CO para intl.
  await initializeDateFormatting('es_CO');
  Intl.defaultLocale = 'es_CO';
  runApp(const ConswareReimbursementsApp());
}

class ConswareReimbursementsApp extends StatelessWidget {
  /// Opcional para pruebas de widgets: permite inyectar un servicio con
  /// un cliente HTTP falso (sin red real). En producción es null.
  final ReimbursementApiService? apiService;

  const ConswareReimbursementsApp({super.key, this.apiService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consware Reembolsos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: HomeShell(apiService: apiService),
    );
  }
}

class HomeShell extends StatefulWidget {
  /// Opcional para pruebas de widgets: servicio con HTTP falso.
  /// Si es null se crea uno real.
  final ReimbursementApiService? apiService;

  const HomeShell({super.key, this.apiService});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final ReimbursementApiService _apiService;
  int _selectedIndex = 0;

  /// Se incrementa cada vez que se entra a "Mis solicitudes"; el listado
  /// escucha el cambio (didUpdateWidget) y repite el GET automáticamente
  /// (p. ej. tras un POST exitoso que cambia a esa pestaña).
  int _listRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ReimbursementApiService();
  }

  @override
  void dispose() {
    // El servicio inyectado lo administra quien lo creó (las pruebas).
    if (widget.apiService == null) _apiService.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) _listRefreshVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      CreateReimbursementScreen(
        apiService: _apiService,
        employeeName: kEmployeeName,
        onSuccess: () => _onTabTapped(1),
      ),
      MyReimbursementsScreen(
        apiService: _apiService,
        employeeName: kEmployeeName,
        refreshVersion: _listRefreshVersion,
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consware Reembolsos'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Crear',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Mis solicitudes',
          ),
        ],
      ),
    );
  }
}
