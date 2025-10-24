import 'package:flutter/material.dart';
import 'database_test_screen.dart';
import 'camera_test_screen.dart';

/// Pantalla principal con navegación entre las diferentes funcionalidades
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DatabaseTestScreen(),
    const CameraTestScreen(),
  ];

  final List<NavigationDestination> _destinations = [
    const NavigationDestination(
      icon: Icon(Icons.storage),
      selectedIcon: Icon(Icons.storage),
      label: 'Base de Datos',
    ),
    const NavigationDestination(
      icon: Icon(Icons.camera_alt),
      selectedIcon: Icon(Icons.camera_alt),
      label: 'Cámara',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _destinations,
        backgroundColor: Colors.grey[50],
        indicatorColor: Colors.deepPurple.withOpacity(0.2),
      ),
    );
  }
}
