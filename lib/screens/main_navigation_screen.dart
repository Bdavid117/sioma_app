import 'package:flutter/material.dart';
import 'person_enrollment_screen.dart';
import 'registered_persons_screen.dart';
import 'database_test_screen.dart';
import 'camera_test_screen.dart';
import 'embedding_test_screen.dart';

/// Pantalla principal con navegación entre las diferentes funcionalidades
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PersonEnrollmentScreen(),
    const RegisteredPersonsScreen(),
    const DatabaseTestScreen(),
    const CameraTestScreen(),
    const EmbeddingTestScreen(),
  ];

  final List<NavigationDestination> _destinations = [
    const NavigationDestination(
      icon: Icon(Icons.person_add),
      selectedIcon: Icon(Icons.person_add),
      label: 'Registro',
    ),
    const NavigationDestination(
      icon: Icon(Icons.people),
      selectedIcon: Icon(Icons.people),
      label: 'Personas',
    ),
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
    const NavigationDestination(
      icon: Icon(Icons.psychology),
      selectedIcon: Icon(Icons.psychology),
      label: 'Embeddings',
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
