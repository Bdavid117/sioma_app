import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/identification_service.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import 'dart:io';
import 'dart:async';

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

  // Configuración del scanner
  static const Duration _scanInterval = Duration(milliseconds: 2000); // Escanear cada 2 segundos
  static const double _identificationThreshold = 0.75; // Umbral más alto para mayor precisión
  static const int _consecutiveScansNeeded = 2; // Necesita 2 detecciones consecutivas
  
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
      // Inicializar servicios
      final cameraInitialized = await _cameraService.initialize();
      final identificationInitialized = await _identificationService.initialize();
      
      if (!cameraInitialized) {
        throw Exception('Error al inicializar cámara');
      }
      
      if (!identificationInitialized) {
        throw Exception('Error al inicializar servicio de identificación');
      }

      // Cargar personas registradas
      _registeredPersons = await _dbService.getAllPersons();
      
      setState(() {
        _isInitialized = true;
        _statusMessage = _registeredPersons.isEmpty 
            ? 'No hay personas registradas. Ve a "Registrar" para agregar personas.'
            : 'Scanner listo. ${_registeredPersons.length} personas en base de datos.';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error de inicialización: $e';
      });
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

    try {
      _scanCount++;
      
      setState(() {
        _statusMessage = '📸 Capturando frame $_scanCount...';
      });

      // Capturar foto automáticamente
      final imagePath = await _cameraService.takePicture(fileName: 'scanner_${DateTime.now().millisecondsSinceEpoch}');
      
      if (imagePath == null) {
        setState(() {
          _statusMessage = '❌ Error al capturar imagen';
        });
        return;
      }

      _lastCapturedPath = imagePath;
      
      setState(() {
        _statusMessage = '🧠 Analizando imagen...';
      });

      // Realizar identificación
      final result = await _identificationService.identifyPerson(
        imagePath,
        threshold: _identificationThreshold,
      );

      await _processIdentificationResult(result);

    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error durante escaneo: $e';
      });
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
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Inicializando cámara...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('Cámara no disponible', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Stack(
      children: [
        // Vista de cámara
        ClipRect(
          child: Transform.scale(
            scale: controller.value.aspectRatio / MediaQuery.of(context).size.aspectRatio,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),

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