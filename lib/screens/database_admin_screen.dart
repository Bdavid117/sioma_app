import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../services/database_service.dart';
import '../utils/app_logger.dart';

/// Pantalla de administración y optimización de la base de datos
class DatabaseAdminScreen extends ConsumerStatefulWidget {
  const DatabaseAdminScreen({super.key});

  @override
  ConsumerState<DatabaseAdminScreen> createState() => _DatabaseAdminScreenState();
}

class _DatabaseAdminScreenState extends ConsumerState<DatabaseAdminScreen> {
  DatabaseStats? _stats;
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando estadísticas...';
    });

    try {
      final dbService = ref.read(databaseServiceProvider);
      final stats = await dbService.getDatabaseStats();

      setState(() {
        _stats = stats;
        _isLoading = false;
        _statusMessage = 'Estadísticas actualizadas';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al cargar estadísticas: $e';
      });
      DatabaseLogger.error('Error loading database stats', e);
    }
  }

  Future<void> _optimizeDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimizar Base de Datos'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta operación:'),
            SizedBox(height: 8),
            Text('• Reconstruirá la base de datos (VACUUM)'),
            Text('• Actualizará estadísticas de índices (ANALYZE)'),
            Text('• Puede tardar varios segundos'),
            SizedBox(height: 16),
            Text(
              'La aplicación no responderá durante este proceso.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Optimizar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Optimizando base de datos...';
    });

    try {
      final dbService = ref.read(databaseServiceProvider);
      await dbService.optimizeDatabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Base de datos optimizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Recargar estadísticas
      await _loadStats();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al optimizar: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de Base de Datos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStats,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Procesando...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Estado
                  if (_statusMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Estadísticas principales
                  const Text(
                    'Estadísticas Generales',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (_stats != null) ...[
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        _buildStatCard(
                          'Personas\nRegistradas',
                          '${_stats!.personsCount}',
                          Icons.people,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Eventos de\nIdentificación',
                          '${_stats!.eventsCount}',
                          Icons.event,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Análisis\nDetallados',
                          '${_stats!.analysisCount}',
                          Icons.analytics,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'Eventos\nPersonalizados',
                          '${_stats!.customEventsCount}',
                          Icons.star,
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Información de almacenamiento
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.storage, color: Colors.deepPurple),
                                SizedBox(width: 8),
                                Text(
                                  'Almacenamiento',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow('Tamaño de la BD', '${_stats!.databaseSizeMB.toStringAsFixed(2)} MB'),
                            _buildInfoRow('Total de registros', '${_stats!.totalRecords}'),
                            _buildInfoRow('Versión de esquema', '4'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Índices activos
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.speed, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Optimizaciones Activas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            const Text('✅ Índice en persons.name'),
                            const Text('✅ Índice en persons.document_id'),
                            const Text('✅ Índice en persons.created_at'),
                            const Text('✅ Índice en events.timestamp'),
                            const Text('✅ Índice en events.person_id'),
                            const Text('✅ Índice en events.identified'),
                            const SizedBox(height: 8),
                            Text(
                              'Total: 11 índices activos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botón de optimización
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _optimizeDatabase,
                    icon: const Icon(Icons.tune),
                    label: const Text('Optimizar Base de Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Información adicional
                  Card(
                    color: Colors.blue[50],
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Consejos de Rendimiento',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('• Optimiza la BD cada 1000 registros nuevos'),
                          Text('• Los índices mejoran la velocidad de búsqueda'),
                          Text('• VACUUM libera espacio de registros eliminados'),
                          Text('• ANALYZE mejora el plan de consultas'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
