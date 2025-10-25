import 'dart:async';
import 'package:camera/camera.dart';
import '../services/face_detection_service.dart';
import '../services/photo_quality_analyzer.dart';
import '../services/identification_service.dart';
import '../utils/app_logger.dart';

/// Servicio para scanner en tiempo real optimizado
/// Procesa frames continuamente con throttling y cooldown
class RealtimeScannerService {
  final FaceDetectionService _faceDetection;
  final PhotoQualityAnalyzer _qualityAnalyzer;
  final IdentificationService _identificationService;

  Timer? _scanTimer;
  bool _isProcessing = false;
  bool _isActive = false;

  // Cooldown para evitar identificar la misma persona repetidamente
  String? _lastIdentifiedPersonId;
  DateTime? _lastIdentificationTime;
  static const int _cooldownSeconds = 5;

  // Estadísticas
  int _framesProcessed = 0;
  int _facesDetected = 0;
  int _identificationsAttempted = 0;
  int _identificationsSuccessful = 0;

  RealtimeScannerService({
    required FaceDetectionService faceDetection,
    required PhotoQualityAnalyzer qualityAnalyzer,
    required IdentificationService identificationService,
  })  : _faceDetection = faceDetection,
        _qualityAnalyzer = qualityAnalyzer,
        _identificationService = identificationService;

  /// Inicia el scanner en tiempo real
  void startScanning({
    required CameraController camera,
    required Function(ScanResult) onResult,
    int intervalSeconds = 2,
  }) {
    if (_isActive) {
      AppLogger.warning('Scanner ya está activo');
      return;
    }

    _isActive = true;
    _resetStatistics();

    AppLogger.info('🎥 Iniciando scanner en tiempo real (intervalo: ${intervalSeconds}s)');

    _scanTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) async {
      if (!_isActive) {
        timer.cancel();
        return;
      }

      if (_isProcessing) {
        AppLogger.debug('⏭️ Saltando frame - procesamiento en curso');
        return;
      }

      await _processFrame(camera, onResult);
    });
  }

  /// Procesa un frame de la cámara
  Future<void> _processFrame(
    CameraController camera,
    Function(ScanResult) onResult,
  ) async {
    _isProcessing = true;
    _framesProcessed++;

    try {
      // 1. Capturar frame
      final image = await camera.takePicture();
      CameraLogger.debug('📸 Frame capturado: ${image.path}');

      // 2. Detectar rostro con ML Kit
      final faceResult = await _faceDetection.detectFaces(image.path);
      
      if (!faceResult.success || !faceResult.hasOneFace) {
        onResult(ScanResult(
          status: ScanStatus.noFace,
          message: faceResult.errorMessage ?? 'Sin rostro detectado',
          framesProcessed: _framesProcessed,
        ));
        return;
      }

      _facesDetected++;

      // 3. Análisis rápido de calidad (solo brillo y contraste)
      final qualityResult = await _quickQualityCheck(image.path);
      
      if (!qualityResult.isOptimal) {
        onResult(ScanResult(
          status: ScanStatus.poorQuality,
          message: 'Calidad insuficiente: ${qualityResult.recommendations.join(", ")}',
          qualityScore: qualityResult.qualityScore,
          framesProcessed: _framesProcessed,
        ));
        return;
      }

      // 4. Verificar cooldown antes de identificar
      if (!_shouldIdentify()) {
        final remainingSeconds = _cooldownSeconds - 
            DateTime.now().difference(_lastIdentificationTime!).inSeconds;
        
        onResult(ScanResult(
          status: ScanStatus.cooldown,
          message: 'Espera ${remainingSeconds}s antes de re-identificar',
          lastPersonId: _lastIdentifiedPersonId,
          framesProcessed: _framesProcessed,
        ));
        return;
      }

      // 5. Identificar persona
      _identificationsAttempted++;
      final identificationResult = await _identificationService.identifyPerson(
        image.path,
      );

      if (identificationResult.isIdentified) {
        _identificationsSuccessful++;
        _lastIdentifiedPersonId = identificationResult.person!.id.toString();
        _lastIdentificationTime = DateTime.now();

        onResult(ScanResult(
          status: ScanStatus.identified,
          message: 'Persona identificada',
          person: identificationResult.person,
          confidence: identificationResult.confidence,
          framesProcessed: _framesProcessed,
          faceQuality: faceResult.analysis?.qualityScore,
        ));
      } else {
        onResult(ScanResult(
          status: ScanStatus.notIdentified,
          message: 'Persona no registrada',
          confidence: identificationResult.confidence,
          framesProcessed: _framesProcessed,
        ));
      }

    } catch (e, stackTrace) {
      AppLogger.error('Error procesando frame', error: e, stackTrace: stackTrace);
      onResult(ScanResult(
        status: ScanStatus.error,
        message: 'Error: $e',
        framesProcessed: _framesProcessed,
      ));
    } finally {
      _isProcessing = false;
    }
  }

  /// Análisis rápido de calidad (sin nitidez para velocidad)
  Future<PhotoQualityResult> _quickQualityCheck(String imagePath) async {
    // Implementación simplificada - solo brillo básico
    // Para producción, usar PhotoQualityAnalyzer completo
    try {
      return await _qualityAnalyzer.analyzePhoto(imagePath);
    } catch (e) {
      return PhotoQualityResult.poor('Error en análisis');
    }
  }

  /// Verifica si debe identificar (cooldown check)
  bool _shouldIdentify() {
    if (_lastIdentificationTime == null) return true;
    
    final timeSinceLastId = DateTime.now().difference(_lastIdentificationTime!);
    return timeSinceLastId.inSeconds >= _cooldownSeconds;
  }

  /// Detiene el scanner
  void stopScanning() {
    if (!_isActive) return;

    _isActive = false;
    _scanTimer?.cancel();
    _scanTimer = null;

    AppLogger.info(
      '🛑 Scanner detenido - Stats: '
      'Frames=${_framesProcessed}, '
      'Rostros=${_facesDetected}, '
      'Identificados=${_identificationsSuccessful}/$_identificationsAttempted'
    );
  }

  /// Resetea las estadísticas
  void _resetStatistics() {
    _framesProcessed = 0;
    _facesDetected = 0;
    _identificationsAttempted = 0;
    _identificationsSuccessful = 0;
    _lastIdentifiedPersonId = null;
    _lastIdentificationTime = null;
  }

  /// Obtiene estadísticas del scanner
  ScannerStatistics getStatistics() {
    return ScannerStatistics(
      framesProcessed: _framesProcessed,
      facesDetected: _facesDetected,
      identificationsAttempted: _identificationsAttempted,
      identificationsSuccessful: _identificationsSuccessful,
      isActive: _isActive,
      isProcessing: _isProcessing,
    );
  }

  /// Resetea el cooldown manualmente
  void resetCooldown() {
    _lastIdentifiedPersonId = null;
    _lastIdentificationTime = null;
    AppLogger.debug('Cooldown reseteado manualmente');
  }

  /// Libera recursos
  void dispose() {
    stopScanning();
    AppLogger.debug('RealtimeScannerService disposed');
  }
}

/// Resultado del escaneo
class ScanResult {
  final ScanStatus status;
  final String message;
  final dynamic person; // Person model
  final double? confidence;
  final double? qualityScore;
  final double? faceQuality;
  final String? lastPersonId;
  final int framesProcessed;

  ScanResult({
    required this.status,
    required this.message,
    this.person,
    this.confidence,
    this.qualityScore,
    this.faceQuality,
    this.lastPersonId,
    required this.framesProcessed,
  });

  bool get isSuccess => status == ScanStatus.identified;
}

/// Estado del escaneo
enum ScanStatus {
  noFace,          // No hay rostro
  poorQuality,     // Calidad insuficiente
  cooldown,        // En período de espera
  identified,      // Persona identificada
  notIdentified,   // Persona no registrada
  error,           // Error en procesamiento
}

/// Estadísticas del scanner
class ScannerStatistics {
  final int framesProcessed;
  final int facesDetected;
  final int identificationsAttempted;
  final int identificationsSuccessful;
  final bool isActive;
  final bool isProcessing;

  ScannerStatistics({
    required this.framesProcessed,
    required this.facesDetected,
    required this.identificationsAttempted,
    required this.identificationsSuccessful,
    required this.isActive,
    required this.isProcessing,
  });

  double get faceDetectionRate {
    if (framesProcessed == 0) return 0.0;
    return facesDetected / framesProcessed;
  }

  double get identificationSuccessRate {
    if (identificationsAttempted == 0) return 0.0;
    return identificationsSuccessful / identificationsAttempted;
  }

  @override
  String toString() {
    return 'ScannerStats(frames: $framesProcessed, faces: $facesDetected, '
        'identified: $identificationsSuccessful/$identificationsAttempted)';
  }
}
