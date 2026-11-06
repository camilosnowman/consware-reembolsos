import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'config/api_config.dart';
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
  const ConswareReimbursementsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consware Reembolsos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ReimbursementApiService _apiService = ReimbursementApiService();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
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
