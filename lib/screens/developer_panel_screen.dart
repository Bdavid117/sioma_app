import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../services/camera_service.dart';
import '../services/pdf_report_generator.dart';
import 'database_test_screen.dart';
import 'camera_test_screen.dart';
import 'embedding_test_screen.dart';
import 'features_demo_screen.dart';
import 'main_navigation_screen.dart';
import 'developer_mode_screen.dart';
import 'realtime_scanner_screen.dart';

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
  bool _isBusy = false;

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

  Future<void> _optimizeDatabase() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _dbService.optimizeDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Base de datos optimizada (ANALYZE + VACUUM)'), backgroundColor: Colors.green),
      );
      await _loadSystemStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error optimizando BD: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _generatePdfReport() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final generator = PDFReportGenerator(_dbService);
      final file = await generator.generateAttendanceReport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📄 Reporte generado: ${file.path.split(Platform.pathSeparator).last}'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error generando PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _clearTempCache() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final tempDir = await getTemporaryDirectory();
      int removed = 0;
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: false)) {
          if (entity is File && (entity.path.endsWith('.jpg') || entity.path.endsWith('.png'))) {
            try { await entity.delete(); removed++; } catch (_) {}
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🧹 Caché temporal limpiado ($removed archivos)'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error limpiando caché: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openDeveloperSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperModeScreen()));
  }

  void _openRealtimeScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RealTimeScannerScreen()));
  }

  Future<void> _exportDatabase() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final dbDir = await getDatabasesPath();
      final src = File(p.join(dbDir, 'sioma_biometric.db'));
      if (!await src.exists()) {
        throw Exception('Archivo de BD no encontrado');
      }
      final docs = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final dst = File(p.join(docs.path, 'sioma_backup_$ts.db'));
      await src.copy(dst.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('💾 BD exportada: ${p.basename(dst.path)}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error exportando BD: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
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
      case 'demo':
        targetScreen = const FeaturesDemoScreen();
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

              // Acciones rápidas técnicas
              _buildQuickActionsCard(),
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
                Expanded(
                  child: _buildToolButton(
                    'Demo Features',
                    Icons.rocket_launch,
                    Colors.purple,
                    'Nuevas funcionalidades v2.0',
                    () => _navigateToTool('demo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas (Técnico)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.6,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: [
                _buildActionChip(
                  label: 'Optimizar BD',
                  icon: Icons.speed,
                  color: Colors.blue,
                  onTap: _optimizeDatabase,
                ),
                _buildActionChip(
                  label: 'Reporte PDF',
                  icon: Icons.picture_as_pdf,
                  color: Colors.red,
                  onTap: _generatePdfReport,
                ),
                _buildActionChip(
                  label: 'Limpiar Caché',
                  icon: Icons.delete_sweep,
                  color: Colors.orange,
                  onTap: _clearTempCache,
                ),
                _buildActionChip(
                  label: 'Exportar BD',
                  icon: Icons.save_alt,
                  color: Colors.green,
                  onTap: _exportDatabase,
                ),
                _buildActionChip(
                  label: 'Scanner Tiempo Real',
                  icon: Icons.qr_code_scanner,
                  color: Colors.teal,
                  onTap: _openRealtimeScanner,
                ),
                _buildActionChip(
                  label: 'Ajustes Desarrollador',
                  icon: Icons.tune,
                  color: Colors.purple,
                  onTap: _openDeveloperSettings,
                ),
              ],
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
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

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
            ],
          ),
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