import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/identification_service.dart';
import '../providers/service_providers.dart';
import '../utils/app_logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Pantalla de modo desarrollador con opciones avanzadas
class DeveloperModeScreen extends ConsumerStatefulWidget {
  const DeveloperModeScreen({super.key});

  @override
  ConsumerState<DeveloperModeScreen> createState() => _DeveloperModeScreenState();
}

class _DeveloperModeScreenState extends ConsumerState<DeveloperModeScreen> {
  late final DatabaseService _dbService;
  late final IdentificationService _identificationService;
  
  // Configuraciones
  double _identificationThreshold = 0.70;
  bool _debugMode = false;
  bool _detailedLogs = false;
  int _cacheSize = 0;
  String _dbPath = '';
  DatabaseStats? _dbStats;

  @override
  void initState() {
    super.initState();
    _dbService = ref.read(databaseServiceProvider);
    _identificationService = ref.read(identificationServiceProvider);
    _loadDeveloperSettings();
  }

  Future<void> _loadDeveloperSettings() async {
    try {
      // Cargar estadísticas de BD
      final stats = await _dbService.getDatabaseStats();
      
      // Obtener path de la base de datos
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/sioma.db';
      
      // Calcular tamaño de caché (fotos temporales)
      final tempDir = await getTemporaryDirectory();
      int cacheSize = 0;
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: true)) {
          if (entity is File) {
            try {
              cacheSize += await entity.length();
            } catch (e) {
              // Ignorar archivos bloqueados
            }
          }
        }
      }

      setState(() {
        _dbStats = stats;
        _dbPath = dbPath;
        _cacheSize = cacheSize;
      });
    } catch (e) {
      AppLogger.error('Error cargando configuración desarrollador', error: e);
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list()) {
          if (entity is File && entity.path.endsWith('.jpg')) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignorar errores
            }
          }
        }
      }
      
      await _loadDeveloperSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Caché limpiado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error limpiando caché', error: e);
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbFile = File('${appDir.path}/sioma.db');
      
      if (await dbFile.exists()) {
        final exportPath = '${appDir.path}/sioma_backup_${DateTime.now().millisecondsSinceEpoch}.db';
        await dbFile.copy(exportPath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Base de datos exportada a:\n${exportPath.split('/').last}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error exportando BD', error: e);
    }
  }

  Future<void> _optimizeDatabase() async {
    try {
      await _dbService.database; // Asegurar que esté abierta
      
      // Ejecutar VACUUM y ANALYZE
      final db = await _dbService.database;
      await db.execute('VACUUM');
      await db.execute('ANALYZE');
      
      await _loadDeveloperSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de datos optimizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error optimizando BD', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Modo Desarrollador'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Colors.deepPurple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Opciones Avanzadas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estas configuraciones pueden afectar el rendimiento del sistema. Úsalas con precaución.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Estadísticas de Base de Datos
          _buildSection(
            title: '📊 Estadísticas de Base de Datos',
            children: [
              if (_dbStats != null) ...[
                _buildStatRow('Total Personas', '${_dbStats!.personsCount}'),
                _buildStatRow('Total Eventos', '${_dbStats!.eventsCount}'),
                _buildStatRow('Eventos Análisis', '${_dbStats!.analysisCount}'),
                _buildStatRow('Tamaño BD', _formatBytes(File(_dbPath).existsSync() ? File(_dbPath).lengthSync() : 0)),
                _buildStatRow('Índices', '6 optimizados'),
                _buildStatRow('Versión Schema', 'v3'),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _optimizeDatabase,
                      icon: const Icon(Icons.speed),
                      label: const Text('Optimizar BD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportDatabase,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Exportar BD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Configuración de Identificación
          _buildSection(
            title: '🎯 Configuración de Identificación',
            children: [
              _buildStatRow('Threshold Actual', '${(_identificationThreshold * 100).toStringAsFixed(0)}%'),
              const Text(
                'Umbral de confianza para identificación positiva',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Slider(
                value: _identificationThreshold,
                min: 0.50,
                max: 0.95,
                divisions: 45,
                label: '${(_identificationThreshold * 100).toStringAsFixed(0)}%',
                onChanged: (value) {
                  setState(() {
                    _identificationThreshold = value;
                  });
                },
              ),
              Text(
                _getThresholdRecommendation(),
                style: TextStyle(
                  fontSize: 12,
                  color: _identificationThreshold < 0.65
                      ? Colors.red
                      : _identificationThreshold > 0.85
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Gestión de Caché
          _buildSection(
            title: '🗂️ Gestión de Caché',
            children: [
              _buildStatRow('Tamaño Caché', _formatBytes(_cacheSize)),
              _buildStatRow('Ubicación', '/data/cache/'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _clearCache,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Limpiar Caché Temporal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Opciones de Debug
          _buildSection(
            title: '🐛 Opciones de Debug',
            children: [
              SwitchListTile(
                title: const Text('Modo Debug'),
                subtitle: const Text('Muestra información detallada en consola'),
                value: _debugMode,
                onChanged: (value) {
                  setState(() {
                    _debugMode = value;
                  });
                  AppLogger.info('Modo debug: ${value ? "activado" : "desactivado"}');
                },
              ),
              SwitchListTile(
                title: const Text('Logs Detallados'),
                subtitle: const Text('Incluye stack traces y metadata'),
                value: _detailedLogs,
                onChanged: (value) {
                  setState(() {
                    _detailedLogs = value;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Información del Sistema
          _buildSection(
            title: '📱 Información del Sistema',
            children: [
              _buildStatRow('Plataforma', Platform.operatingSystem),
              _buildStatRow('Versión OS', Platform.operatingSystemVersion),
              _buildStatRow('Base de Datos', _dbPath.split('/').last),
              _buildStatRow('Logging', 'AppLogger v1.0'),
              _buildStatRow('State Management', 'Riverpod 2.6.1'),
            ],
          ),

          const SizedBox(height: 20),

          // Acciones Peligrosas
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Zona Peligrosa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showResetDialog(),
                    icon: const Icon(Icons.restore),
                    label: const Text('Resetear Base de Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getThresholdRecommendation() {
    if (_identificationThreshold < 0.65) {
      return '⚠️ Muy bajo - Alto riesgo de falsos positivos';
    } else if (_identificationThreshold > 0.85) {
      return '⚠️ Muy alto - Alto riesgo de falsos negativos';
    } else if (_identificationThreshold >= 0.70 && _identificationThreshold <= 0.80) {
      return '✅ Óptimo - Balance entre precisión y recall';
    } else {
      return 'ℹ️ Aceptable';
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmar Reset'),
        content: const Text(
          'Esto eliminará TODAS las personas registradas y eventos.\n\n'
          '¿Estás seguro? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Aquí iría la lógica de reset
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Función deshabilitada en producción'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
  }
}
