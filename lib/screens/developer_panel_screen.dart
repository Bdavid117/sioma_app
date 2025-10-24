import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../services/camera_service.dart';
import 'database_test_screen.dart';
import 'camera_test_screen.dart';
import 'embedding_test_screen.dart';
import 'main_navigation_screen.dart';

/// Panel técnico con herramientas de desarrollador y debugging
class DeveloperPanelScreen extends StatefulWidget {
  const DeveloperPanelScreen({super.key});

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> {
  final DatabaseService _dbService = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final CameraService _cameraService = CameraService();

  Map<String, dynamic> _systemStats = {};
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSystemStats();
  }

  Future<void> _loadSystemStats() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando estadísticas del sistema...';
    });

    try {
      final personsCount = await _dbService.getPersonsCount();
      final eventsCount = await _dbService.getEventsCount();
      final photos = await _cameraService.getSavedPhotos();
      final modelInfo = _embeddingService.getModelInfo();

      setState(() {
        _systemStats = {
          'personas': personsCount,
          'eventos': eventsCount,
          'fotos': photos.length,
          'modeloIA': modelInfo['isInitialized'],
          'modoIA': modelInfo['mode'],
          'dimensionesIA': modelInfo['embeddingSize'],
        };
        _statusMessage = 'Sistema funcionando correctamente';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al cargar estadísticas: $e';
        _isLoading = false;
      });
    }
  }

  void _enableDeveloperMode() {
    MainNavigationController.enableDeveloperMode(context);
  }

  void _navigateToTool(String tool) {
    Widget targetScreen;
    
    switch (tool) {
      case 'database':
        targetScreen = const DatabaseTestScreen();
        break;
      case 'camera':
        targetScreen = const CameraTestScreen();
        break;
      case 'embedding':
        targetScreen = const EmbeddingTestScreen();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Técnico'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemStats,
            tooltip: 'Actualizar estadísticas',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSystemStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estado del sistema
              _buildSystemStatusCard(),
              const SizedBox(height: 16),

              // Estadísticas generales
              _buildSystemStatsCard(),
              const SizedBox(height: 16),

              // Herramientas de desarrollador
              _buildDeveloperToolsCard(),
              const SizedBox(height: 16),

              // Modo desarrollador avanzado
              _buildAdvancedModeCard(),
              const SizedBox(height: 16),

              // Información técnica
              _buildTechnicalInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isLoading ? Icons.hourglass_empty : Icons.check_circle,
                  color: _isLoading ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Estado del Sistema',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.startsWith('Error') ? Colors.red : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatsCard() {
    if (_systemStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas del Sistema',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Personas',
                    value: '${_systemStats['personas']}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Eventos',
                    value: '${_systemStats['eventos']}',
                    icon: Icons.event,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Fotos',
                    value: '${_systemStats['fotos']}',
                    icon: Icons.photo_library,
                    color: Colors.purple,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'IA Estado',
                    value: _systemStats['modeloIA'] ? 'OK' : 'Error',
                    icon: Icons.psychology,
                    color: _systemStats['modeloIA'] ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperToolsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Herramientas de Desarrollo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildToolButton(
                    'Base de Datos',
                    Icons.storage,
                    Colors.indigo,
                    'Gestión directa de SQLite',
                    () => _navigateToTool('database'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToolButton(
                    'Cámara',
                    Icons.camera_alt,
                    Colors.teal,
                    'Pruebas de captura',
                    () => _navigateToTool('camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildToolButton(
                    'Embeddings IA',
                    Icons.psychology,
                    Colors.deepOrange,
                    'Análisis de vectores faciales',
                    () => _navigateToTool('embedding'),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()), // Espacio vacío
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedModeCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Modo Desarrollador Avanzado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Habilita el acceso completo a todas las herramientas de debugging y testing en la navegación principal.',
              style: TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _enableDeveloperMode,
              icon: const Icon(Icons.developer_mode),
              label: const Text('Activar Modo Completo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información Técnica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Versión', 'SIOMA v1.0'),
            _buildInfoRow('Base de Datos', 'SQLite Local'),
            _buildInfoRow('IA', '${_systemStats['modoIA']} (${_systemStats['dimensionesIA']}D)'),
            _buildInfoRow('Almacenamiento', '100% Offline'),
            _buildInfoRow('Arquitectura', 'Flutter + TensorFlow Lite'),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(
    String title,
    IconData icon,
    Color color,
    String description,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}