import 'package:flutter/material.dart';
import 'identification_screen.dart';
import 'realtime_scanner_screen.dart';
import 'person_enrollment_screen.dart';
import 'registered_persons_screen.dart';
import 'database_test_screen.dart';
import 'camera_test_screen.dart';
import 'embedding_test_screen.dart';
import 'developer_panel_screen.dart';

/// Pantalla principal con navegación optimizada para usuarios finales
/// Incluye panel de desarrollador para funciones técnicas
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isDeveloperMode = false;

  // Pantallas de producción (para usuarios finales)
  final List<Widget> _productionScreens = [
    const IdentificationScreen(),
    const RealTimeScannerScreen(),
    const PersonEnrollmentScreen(),
    const RegisteredPersonsScreen(),
    const DeveloperPanelScreen(),
  ];

  // Pantallas de desarrollo (para técnicos/desarrolladores)
  final List<Widget> _developerScreens = [
    const IdentificationScreen(),
    const RealTimeScannerScreen(),
    const PersonEnrollmentScreen(),
    const RegisteredPersonsScreen(),
    const DatabaseTestScreen(),
    const CameraTestScreen(),
    const EmbeddingTestScreen(),
  ];

  // Navegación de producción
  final List<NavigationDestination> _productionDestinations = [
    const NavigationDestination(
      icon: Icon(Icons.person_search),
      selectedIcon: Icon(Icons.person_search_outlined),
      label: 'Identificar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.scanner),
      selectedIcon: Icon(Icons.scanner_outlined),
      label: 'Scanner',
    ),
    const NavigationDestination(
      icon: Icon(Icons.person_add_alt_1),
      selectedIcon: Icon(Icons.person_add_alt_1_outlined),
      label: 'Registrar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.groups),
      selectedIcon: Icon(Icons.groups_outlined),
      label: 'Gestionar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.developer_mode),
      selectedIcon: Icon(Icons.developer_mode_outlined),
      label: 'Técnico',
    ),
  ];

  // Navegación de desarrollador
  final List<NavigationDestination> _developerDestinations = [
    const NavigationDestination(
      icon: Icon(Icons.person_search),
      selectedIcon: Icon(Icons.person_search_outlined),
      label: 'Identificar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.scanner),
      selectedIcon: Icon(Icons.scanner_outlined),
      label: 'Scanner',
    ),
    const NavigationDestination(
      icon: Icon(Icons.person_add_alt_1),
      selectedIcon: Icon(Icons.person_add_alt_1_outlined),
      label: 'Registro',
    ),
    const NavigationDestination(
      icon: Icon(Icons.groups),
      selectedIcon: Icon(Icons.groups_outlined),
      label: 'Personas',
    ),
    const NavigationDestination(
      icon: Icon(Icons.storage),
      selectedIcon: Icon(Icons.storage_outlined),
      label: 'BD',
    ),
    const NavigationDestination(
      icon: Icon(Icons.camera_alt),
      selectedIcon: Icon(Icons.camera_alt_outlined),
      label: 'Cámara',
    ),
    const NavigationDestination(
      icon: Icon(Icons.psychology),
      selectedIcon: Icon(Icons.psychology_outlined),
      label: 'IA',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentScreens = _isDeveloperMode ? _developerScreens : _productionScreens;
    final currentDestinations = _isDeveloperMode ? _developerDestinations : _productionDestinations;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: currentScreens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: currentDestinations,
        backgroundColor: _isDeveloperMode ? Colors.orange[50] : Colors.grey[50],
        indicatorColor: _isDeveloperMode 
            ? Colors.orange.withValues(alpha: 0.3)
            : Colors.deepPurple.withValues(alpha: 0.2),
        elevation: 8,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      appBar: _isDeveloperMode ? AppBar(
        title: const Text('🔧 MODO DESARROLLADOR'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _exitDeveloperMode,
            tooltip: 'Salir del modo desarrollador',
          ),
        ],
      ) : null,
    );
  }

  void _exitDeveloperMode() {
    setState(() {
      _isDeveloperMode = false;
      _currentIndex = 0; // Volver a la primera pestaña
    });
  }

  void enableDeveloperMode() {
    setState(() {
      _isDeveloperMode = true;
      _currentIndex = 0;
    });
  }
}

// Clase pública para permitir acceso desde otras pantallas
class MainNavigationController {
  static void enableDeveloperMode(BuildContext context) {
    final mainNav = context.findAncestorStateOfType<_MainNavigationScreenState>();
    mainNav?.enableDeveloperMode();
  }
}
