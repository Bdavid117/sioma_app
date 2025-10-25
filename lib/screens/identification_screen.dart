import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/enhanced_identification_service.dart';
import '../services/identification_service.dart';
import '../services/database_service.dart';
import '../screens/smart_camera_capture_screen.dart';
import '../models/person.dart';
import '../utils/app_logger.dart';
import '../providers/service_providers.dart';
import '../providers/state_providers.dart';
import 'dart:io';

/// Pantalla principal de identificación 1:N en tiempo real
class IdentificationScreen extends ConsumerStatefulWidget {
  const IdentificationScreen({super.key});

  @override
  ConsumerState<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  // Estado de la identificación
  EnhancedIdentificationResult? _lastResult;
  String _statusMessage = '';
  double _currentThreshold = 0.6; // Umbral ajustado según requerimiento
  String? _currentImagePath;

  // Estadísticas
  IdentificationStats? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeService();
      _loadStats();
    });
  }

  Future<void> _initializeService() async {
    final processNotifier = ref.read(identificationProcessProvider.notifier);
    final enhancedService = ref.read(enhancedIdentificationServiceProvider);
    
    processNotifier.startProcessing();
    setState(() {
      _statusMessage = 'Inicializando servicio mejorado con ML Kit...';
    });

    try {
      final success = await enhancedService.initialize();
      if (success) {
        setState(() {
          _currentThreshold = 0.6; // Umbral configurado
          _statusMessage = '✅ Sistema mejorado listo (ML Kit + Embeddings)';
        });
        processNotifier.stopScanning();
      } else {
        setState(() {
          _statusMessage = 'Error al inicializar el servicio';
        });
        processNotifier.setError('Error al inicializar el servicio');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      processNotifier.setError('Error: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final identificationService = ref.read(identificationServiceProvider);
      final stats = await identificationService.getIdentificationStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      BiometricLogger.error('Error loading stats', e);
    }
  }

  /// Captura imagen e inicia proceso de identificación
  Future<void> _captureAndIdentify() async {
    try {
      setState(() {
        _statusMessage = 'Abriendo cámara inteligente...';
      });

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SmartCameraCaptureScreen(
            personName: 'Identificación',
            documentId: 'ID-${DateTime.now().millisecondsSinceEpoch}',
            autoCapture: true, // Modo automático para mejor calidad
          ),
        ),
      );

      if (imagePath != null) {
        await _performIdentification(imagePath);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al capturar imagen: $e';
      });
    }
  }

  /// Realiza el proceso de identificación 1:N MEJORADO con ML Kit
  Future<void> _performIdentification(String imagePath) async {
    final processNotifier = ref.read(identificationProcessProvider.notifier);
    final enhancedService = ref.read(enhancedIdentificationServiceProvider);
    final eventsNotifier = ref.read(eventsProvider.notifier);
    
    processNotifier.startProcessing();
    setState(() {
      _statusMessage = '🔍 Analizando con ML Kit + Embeddings...';
      _currentImagePath = imagePath;
      _lastResult = null;
    });

    try {
      // Realizar identificación mejorada 1:N con ML Kit
      final result = await enhancedService.identifyPersonWithMLKit(
        imagePath,
        threshold: _currentThreshold,
        strictMode: false, // Modo balanceado
      );

      setState(() {
        _lastResult = result;
        _statusMessage = result.message;
      });

      // Actualizar estado de Riverpod
      if (result.identified && result.person != null) {
        processNotifier.setIdentificationResult(
          personName: result.person!.name,
          confidence: result.confidence!,
        );
        
        // Log del boost ML Kit
        if (result.mlKitBoost != null && result.mlKitBoost! > 0) {
          AppLogger.info('⭐ ML Kit boost: +${(result.mlKitBoost! * 100).toStringAsFixed(1)}%');
        }
      } else {
        processNotifier.setNoMatch();
      }

      // Actualizar estadísticas
      await _loadStats();

      // Mostrar resultado detallado
      if (mounted) {
        _showEnhancedResultDialog(result);
      }
    } catch (e) {
      final processNotifier = ref.read(identificationProcessProvider.notifier);
      processNotifier.setError('Error durante identificación: $e');
      setState(() {
        _statusMessage = 'Error durante identificación: $e';
      });
    }
  }

  /// Muestra diálogo con resultado MEJORADO de identificación
  void _showEnhancedResultDialog(EnhancedIdentificationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.identified ? Icons.verified : 
              result.success ? Icons.help_outline : Icons.error,
              color: result.identified ? Colors.green : 
                     result.success ? Colors.orange : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.identified ? '✅ Identificado' : 
                result.success ? '❌ No Identificado' : '⚠️ Error',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen capturada
              if (_currentImagePath != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_currentImagePath!),
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // NUEVO: Información de calidad ML Kit
              if (result.mlKitValidation != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎯 ML Kit Face Detection:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      _buildResultRow('  Calidad facial:', 
                        '${(result.faceQuality * 100).toStringAsFixed(1)}%'),
                      if (result.mlKitValidation!.analysis != null) ...[
                        _buildResultRow('  Rostro centrado:', 
                          result.mlKitValidation!.analysis!.isCentered ? 'Sí ✅' : 'No ❌'),
                        _buildResultRow('  Ángulo cabeza:', 
                          '${result.mlKitValidation!.analysis!.headAngle.toStringAsFixed(1)}°'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Información del resultado de identificación
              if (result.identified && result.person != null) ...[
                _buildResultRow('👤 Nombre:', result.person!.name),
                _buildResultRow('📄 Documento:', result.person!.documentId),
                _buildResultRow('📅 Registrado:', _formatDate(result.person!.createdAt)),
                const Divider(),
                _buildResultRow('🎯 Confianza Final:', '${(result.confidence! * 100).toStringAsFixed(1)}%'),
                if (result.baseConfidence != null)
                  _buildResultRow('  Confianza Base:', '${(result.baseConfidence! * 100).toStringAsFixed(1)}%'),
                if (result.mlKitBoost != null && result.mlKitBoost! > 0)
                  _buildResultRow('  Boost ML Kit:', '+${(result.mlKitBoost! * 100).toStringAsFixed(1)}% ⭐'),
                _buildResultRow('⏱️ Tiempo:', '${result.processingTimeMs}ms'),
              ] else if (result.success && !result.identified) ...[
                _buildResultRow('❌ Estado:', 'Persona no reconocida'),
                if (result.bestCandidate != null)
                  _buildResultRow('🔍 Mejor coincidencia:',
                    '${result.bestCandidate!.person.name} (${(result.bestCandidate!.adjustedConfidence * 100).toStringAsFixed(1)}%)'),
                _buildResultRow('📊 Umbral requerido:', '${(_currentThreshold * 100).toStringAsFixed(1)}%'),
                if (result.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('💡 Recomendaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...result.recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• $rec', style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ] else if (!result.success) ...[
                _buildResultRow('⚠️ Error:', result.message),
                if (result.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('💡 Recomendaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...result.recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• $rec', style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ],

              const SizedBox(height: 16),

              // Lista de candidatos principales
              if (result.allCandidates.isNotEmpty) ...[
                const Text(
                  'Top candidatos evaluados:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.allCandidates.take(3).map((candidate) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: candidate.adjustedConfidence >= _currentThreshold
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(candidate.person.name),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(candidate.adjustedConfidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: candidate.adjustedConfidence >= _currentThreshold
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (candidate.mlKitBoost > 0)
                              Text(
                                '+${(candidate.mlKitBoost * 100).toStringAsFixed(1)}% ⭐',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (result.identified && result.person != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPersonHistory(result.person!);
              },
              child: const Text('Ver Historial'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _captureAndIdentify();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Nueva Identificación'),
          ),
        ],
      ),
    );
  }

  /// Muestra el historial de una persona identificada
  void _showPersonHistory(Person person) async {
    try {
      final events = await DatabaseService().getEventsByPerson(person.id!);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Historial: ${person.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: events.isEmpty
                ? const Center(child: Text('No hay eventos registrados'))
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        leading: Icon(
                          event.identified ? Icons.check_circle : Icons.help_outline,
                          color: event.identified ? Colors.green : Colors.orange,
                        ),
                        title: Text(_formatDateTime(event.timestamp)),
                        subtitle: Text(
                          event.confidence != null
                              ? 'Confianza: ${(event.confidence! * 100).toStringAsFixed(1)}%'
                              : 'Sin datos de confianza',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar historial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox.shrink();

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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total Eventos',
                    value: '${_stats!.totalEvents}',
                    icon: Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Identificados',
                    value: '${_stats!.identifiedCount}',
                    icon: Icons.check_circle,
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
                    label: 'Tasa de ID',
                    value: '${_stats!.identificationRatePercent.toStringAsFixed(1)}%',
                    icon: Icons.percent,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Confianza Prom.',
                    value: '${_stats!.averageConfidencePercent.toStringAsFixed(1)}%',
                    icon: Icons.psychology,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Threshold de Identificación: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${(_currentThreshold * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _currentThreshold,
              min: 0.5,
              max: 0.95,
              divisions: 45,
              onChanged: (value) {
                setState(() {
                  _currentThreshold = value;
                });
              },
              label: '${(_currentThreshold * 100).toStringAsFixed(0)}%',
            ),
            Text(
              _currentThreshold < 0.6
                  ? 'Baja sensibilidad - Más falsos positivos'
                  : _currentThreshold < 0.8
                      ? 'Sensibilidad equilibrada - Recomendado'
                      : 'Alta sensibilidad - Más falsos negativos',
              style: TextStyle(
                fontSize: 12,
                color: _currentThreshold < 0.6
                    ? Colors.red
                    : _currentThreshold < 0.8
                        ? Colors.green
                        : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastResult() {
    if (_lastResult == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
                Icon(
                Icons.person_search,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Sin identificaciones recientes',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa el botón "Identificar Persona" para comenzar',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lastResult!.identified ? Icons.check_circle : Icons.help_outline,
                  color: _lastResult!.identified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Último Resultado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lastResult!.identified && _lastResult!.person != null) ...[
              Text('Persona: ${_lastResult!.person!.name}'),
              Text('Documento: ${_lastResult!.person!.documentId}'),
              Text('Confianza: ${(_lastResult!.confidence! * 100).toStringAsFixed(1)}%'),
            ] else ...[
              Text('Estado: Persona no reconocida'),
              if (_lastResult!.bestCandidate != null)
                Text('Mejor coincidencia: ${(_lastResult!.bestCandidate!.adjustedConfidence * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Observar el estado del proceso de identificación
    final processState = ref.watch(identificationProcessProvider);
    final isProcessing = processState.isProcessing;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identificación de Personas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Actualizar estadísticas',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estadísticas del sistema
              _buildStatsCard(),
              const SizedBox(height: 16),

              // Control de threshold
              _buildThresholdControl(),
              const SizedBox(height: 16),

              // Último resultado
              _buildLastResult(),
              const SizedBox(height: 24),

              // Botón principal de identificación
              ElevatedButton.icon(
                onPressed: isProcessing ? null : _captureAndIdentify,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_search),
                label: Text(isProcessing ? 'Procesando...' : 'Identificar Persona'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),

              const SizedBox(height: 16),

              // Estado del sistema
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.startsWith('Error') ? Icons.error : Icons.info,
                        color: _statusMessage.startsWith('Error') ? Colors.red : Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage.isEmpty ? 'Sistema listo para identificación' : _statusMessage,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? Colors.deepPurple).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.deepPurple),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.deepPurple,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}