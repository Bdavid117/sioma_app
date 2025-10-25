import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/identification_service.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import '../models/analysis_event.dart';
import '../utils/app_logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';

/// Scanner automático que detecta personas registradas en tiempo real
class RealTimeScannerScreen extends StatefulWidget {
  const RealTimeScannerScreen({super.key});

  @override
  State<RealTimeScannerScreen> createState() => _RealTimeScannerScreenState();
}

class _RealTimeScannerScreenState extends State<RealTimeScannerScreen> {
  final CameraService _cameraService = CameraService();
  final IdentificationService _identificationService = IdentificationService();
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = false;
  bool _isInitialized = false;
  String _statusMessage = 'Inicializando scanner...';
  Person? _detectedPerson;
  double _confidence = 0.0;
  Timer? _scanTimer;
  String? _lastCapturedPath;
  int _scanCount = 0;
  List<Person> _registeredPersons = [];

  // Configuración del scanner ULTRA-RÁPIDO
  static const Duration _scanInterval = Duration(milliseconds: 800); // Escanear cada 800ms
  static const double _identificationThreshold = 0.70; // Umbral optimizado para velocidad
  static const int _consecutiveScansNeeded = 2; // Necesita 2 detecciones consecutivas
  
  // Cache para optimización de rendimiento
  final Map<String, List<double>> _embeddingCache = {}; // Cache de embeddings generados
  final Map<int, DateTime> _personLastSeen = {}; // Última vez que se vio cada persona
  
  int _consecutiveDetections = 0;
  Person? _lastDetectedPerson;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  @override
  void dispose() {
    _stopScanning();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initializeScanner() async {
    setState(() {
      _statusMessage = 'Inicializando cámara y servicios...';
    });

    try {
      // PASO 1: Cargar personas registradas
      setState(() {
        _statusMessage = '📂 Cargando base de datos...';
      });
      
      _registeredPersons = await _dbService.getAllPersons();
      
      if (_registeredPersons.isEmpty) {
        setState(() {
          _isInitialized = true;
          _statusMessage = '⚠️ No hay personas registradas.\nVe a "Registrar" para agregar personas.';
        });
        return;
      }

      // PASO 2: Inicializar servicio de identificación
      setState(() {
        _statusMessage = '🧠 Inicializando IA de reconocimiento...';
      });
      
      final identificationInitialized = await _identificationService.initialize();
      if (!identificationInitialized) {
        throw Exception('Error al inicializar servicio de identificación');
      }

      // PASO 3: Inicializar cámara con reintentos
      setState(() {
        _statusMessage = '📷 Configurando cámara...';
      });
      
      bool cameraInitialized = false;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (!cameraInitialized && attempts < maxAttempts) {
        attempts++;
        
        setState(() {
          _statusMessage = '📷 Intento $attempts/$maxAttempts de inicialización de cámara...';
        });
        
        try {
          cameraInitialized = await _cameraService.initialize();
          if (cameraInitialized) {
            // Esperar un poco más para que la cámara esté completamente lista
            await Future.delayed(const Duration(milliseconds: 1500));
            break;
          }
        } catch (e) {
          CameraLogger.warning('Intento $attempts fallido: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: attempts)); // Espera incremental
          }
        }
      }
      
      if (!cameraInitialized) {
        // Modo sin cámara - permite usar capturas manuales
        setState(() {
          _isInitialized = true;
          _statusMessage = '⚠️ Cámara no disponible.\nUsa "Identificar" para captura manual.\n\n${_registeredPersons.length} personas registradas.';
        });
        return;
      }

      // PASO 4: Verificar que la cámara funciona correctamente
      setState(() {
        _statusMessage = '✅ Verificando funcionamiento de cámara...';
      });
      
      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Controlador de cámara no inicializado correctamente');
      }

      // ÉXITO: Scanner completamente funcional
      setState(() {
        _isInitialized = true;
        _statusMessage = '✅ Scanner listo.\n${_registeredPersons.length} personas registradas.\nPresiona "Iniciar Scanner" para comenzar.';
      });

    } catch (e) {
      setState(() {
        _isInitialized = false;
        _statusMessage = '❌ Error: $e\n\nIntenta reinicializar o usa modo manual.';
      });
      AppLogger.error('Error completo de inicialización', e);
    }
  }

  void _startScanning() {
    if (!_isInitialized || _isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = '🔍 Escaneando... Coloca tu rostro en el marco';
      _scanCount = 0;
      _consecutiveDetections = 0;
      _lastDetectedPerson = null;
    });

    _scanTimer = Timer.periodic(_scanInterval, (timer) {
      _performScan();
    });
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    
    setState(() {
      _isScanning = false;
      _statusMessage = _registeredPersons.isEmpty
          ? 'Scanner detenido. No hay personas registradas.'
          : 'Scanner detenido. Presiona "Iniciar Scanner" para comenzar.';
      _detectedPerson = null;
      _confidence = 0.0;
      _consecutiveDetections = 0;
      _lastDetectedPerson = null;
    });
  }

  Future<void> _performScan() async {
    if (!_isScanning || !_isInitialized) return;

    final scanStartTime = DateTime.now();
    
    try {
      _scanCount++;
      
      setState(() {
        _statusMessage = '📸 Escaneando $_scanCount...';
      });

      // OPTIMIZACIÓN 1: Captura rápida con resolución reducida
      final imagePath = await _cameraService.takePicture(fileName: 'scan_fast_${_scanCount}_${scanStartTime.millisecondsSinceEpoch}');
      
      if (imagePath == null) {
        setState(() {
          _statusMessage = '❌ Error al capturar imagen';
        });
        return;
      }

      _lastCapturedPath = imagePath;
      
      setState(() {
        _statusMessage = '⚡ Análisis ultra-rápido...';
      });

      // OPTIMIZACIÓN 2: Verificar cache de embeddings primero
      List<double>? cachedEmbedding = _embeddingCache[imagePath];
      
      if (cachedEmbedding == null) {
        // OPTIMIZACIÓN 3: Generar embedding con prioridad de velocidad
        cachedEmbedding = await _generateFastEmbedding(imagePath);
        if (cachedEmbedding != null) {
          _embeddingCache[imagePath] = cachedEmbedding;
          // Limpiar cache antiguo para memoria
          if (_embeddingCache.length > 10) {
            final oldestKey = _embeddingCache.keys.first;
            _embeddingCache.remove(oldestKey);
          }
        }
      }

      if (cachedEmbedding == null) {
        setState(() {
          _statusMessage = '❌ Error generando embedding';
        });
        return;
      }

      // OPTIMIZACIÓN 4: Comparación paralela con personas registradas
      final identificationResult = await _performFastIdentification(cachedEmbedding, imagePath);
      
      // OPTIMIZACIÓN 5: Registrar evento de análisis automáticamente
      await _registerAnalysisEvent(identificationResult, imagePath, scanStartTime);
      
      final scanEndTime = DateTime.now();
      final totalTime = scanEndTime.difference(scanStartTime).inMilliseconds;
      
      BiometricLogger.info('Escaneo completado en ${totalTime}ms');

      await _processIdentificationResult(identificationResult);

    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error durante escaneo: $e';
      });
      BiometricLogger.error('Error en escaneo rápido', e);
    }
  }

  /// Genera embedding optimizado para velocidad
  Future<List<double>?> _generateFastEmbedding(String imagePath) async {
    try {
      // Usar el servicio de embedding con configuración de velocidad
      return await _identificationService.faceEmbeddingService.generateEmbedding(imagePath);
    } catch (e) {
      BiometricLogger.error('Error generando embedding rápido', e);
      return null;
    }
  }

  /// Realiza identificación ultra-rápida comparando con todas las personas
  Future<IdentificationResult> _performFastIdentification(List<double> embedding, String imagePath) async {
    double bestSimilarity = 0.0;
    Person? bestMatch;
    final List<PersonSimilarity> candidates = [];

    // Comparación paralela optimizada
    for (final person in _registeredPersons) {
      try {
        // Parsear embedding de la persona
        final personEmbedding = _parseEmbeddingFromJson(person.embedding);
        
        // Calcular similitud usando coseno (más rápido que euclidiana)
        final similarity = _calculateCosineSimilarity(embedding, personEmbedding);
        
        candidates.add(PersonSimilarity(
          person: person, 
          similarity: similarity,
          confidence: similarity,
        ));
        
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = person;
        }
      } catch (e) {
        BiometricLogger.debug('Error comparando con ${person.name}: $e');
        continue;
      }
    }

    // Determinar si hay match válido
    final hasMatch = bestSimilarity >= _identificationThreshold && bestMatch != null;

    if (hasMatch) {
      // Actualizar última vez vista
      _personLastSeen[bestMatch!.id!] = DateTime.now();
      
      return IdentificationResult.identified(
        bestMatch,
        confidence: bestSimilarity,
        allCandidates: candidates,
      );
    } else {
      final bestCandidate = candidates.isNotEmpty 
          ? candidates.reduce((a, b) => a.similarity > b.similarity ? a : b)
          : null;
          
      return IdentificationResult.noMatch(
        'Confianza insuficiente (${(bestSimilarity * 100).toStringAsFixed(1)}% < ${(_identificationThreshold * 100).toStringAsFixed(1)}%)',
        bestCandidate: bestCandidate,
        allCandidates: candidates,
      );
    }
  }

  /// Calcula similitud coseno (más rápido que distancia euclidiana)
  double _calculateCosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Registra evento de análisis del scanner automáticamente
  Future<void> _registerAnalysisEvent(
    IdentificationResult result, 
    String imagePath, 
    DateTime startTime,
  ) async {
    try {
      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;
      
      AnalysisEvent event;
      
      if (result.isIdentified && result.person != null) {
        event = AnalysisEvent.scanner(
          imagePath: imagePath,
          wasSuccessful: true,
          personId: result.person!.id,
          personName: result.person!.name,
          confidence: result.confidence,
          processingTime: processingTime,
          additionalMetadata: {
            'scan_number': _scanCount,
            'consecutive_detections': _consecutiveDetections,
            'required_confirmations': _consecutiveScansNeeded,
            'cache_hit': _embeddingCache.containsKey(imagePath),
            'registered_persons_count': _registeredPersons.length,
            'fast_mode': true,
          },
        );
      } else {
        event = AnalysisEvent.scanner(
          imagePath: imagePath,
          wasSuccessful: false,
          processingTime: processingTime,
          additionalMetadata: {
            'scan_number': _scanCount,
            'best_similarity': result.bestCandidate?.similarity,
            'no_match_reason': result.isError ? result.errorMessage : result.noMatchReason,
            'cache_hit': _embeddingCache.containsKey(imagePath),
            'registered_persons_count': _registeredPersons.length,
            'fast_mode': true,
          },
        );
      }
      
      // Guardar en base de datos
      await _dbService.insertAnalysisEvent(event);
      
    } catch (e) {
      BiometricLogger.error('Error registrando evento de scanner', e);
    }
  }

  Future<void> _processIdentificationResult(IdentificationResult result) async {
    if (result.isIdentified && result.person != null) {
      // Verificar si es la misma persona detectada consecutivamente
      if (_lastDetectedPerson?.id == result.person!.id) {
        _consecutiveDetections++;
      } else {
        _consecutiveDetections = 1;
        _lastDetectedPerson = result.person;
      }

      setState(() {
        _detectedPerson = result.person;
        _confidence = result.confidence! * 100;
        _statusMessage = _consecutiveDetections >= _consecutiveScansNeeded
            ? '✅ CONFIRMADO: ${result.person!.name} (${_confidence.toStringAsFixed(1)}%)'
            : '🔍 Detectando: ${result.person!.name} ($_consecutiveDetections/$_consecutiveScansNeeded confirmaciones)';
      });

      // Si hemos confirmado la detección, detener scanner y mostrar resultado
      if (_consecutiveDetections >= _consecutiveScansNeeded) {
        _stopScanning();
        await _showPersonDetectedDialog(result.person!);
      }

    } else {
      // No se detectó persona o confianza muy baja
      _consecutiveDetections = 0;
      _lastDetectedPerson = null;
      
      setState(() {
        _detectedPerson = null;
        _confidence = 0.0;
        _statusMessage = result.bestCandidate != null
            ? '🔍 Persona no registrada (mejor coincidencia: ${(result.bestCandidate!.similarity * 100).toStringAsFixed(1)}%)'
            : '🔍 Buscando personas registradas...';
      });
    }
  }

  Future<void> _showPersonDetectedDialog(Person person) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 8),
            const Text('¡Persona Detectada!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastCapturedPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_lastCapturedPath!),
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              person.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('Documento: ${person.documentId}'),
            Text('Confianza: ${_confidence.toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            Text(
              'Registrado: ${_formatDate(person.createdAt)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startScanning(); // Continuar escaneando
            },
            child: const Text('Continuar Escaneando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Automático'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScanning : _initializeScanner,
            tooltip: _isScanning ? 'Detener scanner' : 'Reinicializar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Vista de cámara
          Expanded(
            flex: 3,
            child: _buildCameraPreview(),
          ),

          // Panel de estado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(),
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_detectedPerson != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_detectedPerson!.name} - ${_confidence.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Controles
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Botón principal
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized ? (_isScanning ? _stopScanning : _startScanning) : null,
                    icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isScanning ? 'Detener Scanner' : 'Iniciar Scanner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Estadísticas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip('Personas', '${_registeredPersons.length}', Icons.people),
                    _buildStatChip('Escaneos', '$_scanCount', Icons.scanner),
                    _buildStatChip('Umbral', '${(_identificationThreshold * 100).toInt()}%', Icons.tune),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    // Estados de inicialización
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage.contains('Inicializando') ? 'Inicializando scanner...' : _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Estado: Inicializado pero sin cámara
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Cámara no disponible',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scanner en modo manual',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _reinitializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Intentar nuevamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Estado: Cámara funcionando correctamente
    Widget cameraWidget;
    try {
      cameraWidget = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width / controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    } catch (e) {
      cameraWidget = Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error en vista de cámara',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _reinitializeCamera,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        cameraWidget,
        // Overlay con guías del rostro
        CustomPaint(
          size: Size.infinite,
          painter: ScannerOverlayPainter(
            isScanning: _isScanning,
            hasDetection: _detectedPerson != null,
          ),
        ),
      ],
    );
  }

  /// Reinicializa la cámara si hay problemas
  Future<void> _reinitializeCamera() async {
    setState(() {
      _isInitialized = false;
      _isScanning = false;
      _statusMessage = 'Reintentando inicialización...';
    });

    // Esperar un poco antes de reinicializar
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      await _cameraService.dispose();
    } catch (e) {
      CameraLogger.warning('Error al cerrar cámara anterior: $e');
    }

    await _initializeScanner();
  }

  Color _getStatusColor() {
    if (!_isInitialized) return Colors.grey;
    if (_detectedPerson != null) return Colors.green;
    if (_isScanning) return Colors.blue;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (!_isInitialized) return Icons.hourglass_empty;
    if (_detectedPerson != null) return Icons.check_circle;
    if (_isScanning) return Icons.search;
    return Icons.face;
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter para el overlay del scanner
class ScannerOverlayPainter extends CustomPainter {
  final bool isScanning;
  final bool hasDetection;

  ScannerOverlayPainter({
    required this.isScanning,
    required this.hasDetection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Color según el estado
    if (hasDetection) {
      paint.color = Colors.green;
    } else if (isScanning) {
      paint.color = Colors.blue;
    } else {
      paint.color = Colors.white.withValues(alpha: 0.7);
    }

    // Marco del rostro centrado
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final faceWidth = size.width * 0.6;
    final faceHeight = faceWidth * 1.2;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: faceWidth,
      height: faceHeight,
    );

    // Dibujar marco redondeado
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      paint,
    );

    // Esquinas resaltadas
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Línea de escaneo animada (solo cuando está escaneando)
    if (isScanning && !hasDetection) {
      final scanLinePaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.8)
        ..strokeWidth = 2.0;
      
      final scanY = rect.top + (rect.height * 0.5); // Línea en el centro
      canvas.drawLine(
        Offset(rect.left + 10, scanY),
        Offset(rect.right - 10, scanY),
        scanLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===================== MÉTODOS AUXILIARES PARA EMBEDDINGS =====================

/// Parsea un embedding desde JSON string a List<double>
List<double> _parseEmbeddingFromJson(String embeddingJson) {
  try {
    // Si es una lista JSON simple
    if (embeddingJson.startsWith('[')) {
      final List<dynamic> parsed = List<dynamic>.from(
        embeddingJson
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => double.tryParse(e.trim()) ?? 0.0)
      );
      return parsed.cast<double>();
    }
    
    // Si son valores separados por coma
    return embeddingJson
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0.0)
        .toList();
  } catch (e) {
    return List.filled(512, 0.0); // Fallback
  }
}

/// Calcula similitud coseno normalizada
double _calculateCosineSimilarity(List<double> embedding1, List<double> embedding2) {
  if (embedding1.length != embedding2.length) return 0.0;

  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;

  for (int i = 0; i < embedding1.length; i++) {
    dotProduct += embedding1[i] * embedding2[i];
    normA += embedding1[i] * embedding1[i];
    normB += embedding2[i] * embedding2[i];
  }

  final denominator = sqrt(normA) * sqrt(normB);
  if (denominator == 0) return 0.0;

  return dotProduct / denominator;
}