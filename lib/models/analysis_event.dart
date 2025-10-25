/// Modelo para registrar eventos de análisis de reconocimiento facial
/// Almacena metadatos detallados de cada intento de identificación
class AnalysisEvent {
  final int? id;
  final String imagePath;
  final DateTime timestamp;
  final String analysisType; // 'identification', 'registration', 'scanner'
  final bool wasSuccessful;
  final int? identifiedPersonId;
  final String? identifiedPersonName;
  final double? confidence;
  final int processingTimeMs;
  final Map<String, dynamic> metadata;
  final String deviceInfo;
  final String appVersion;

  AnalysisEvent({
    this.id,
    required this.imagePath,
    required this.timestamp,
    required this.analysisType,
    required this.wasSuccessful,
    this.identifiedPersonId,
    this.identifiedPersonName,
    this.confidence,
    required this.processingTimeMs,
    required this.metadata,
    required this.deviceInfo,
    required this.appVersion,
  });

  /// Convierte el modelo a mapa para almacenar en BD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'analysis_type': analysisType,
      'was_successful': wasSuccessful ? 1 : 0,
      'identified_person_id': identifiedPersonId,
      'identified_person_name': identifiedPersonName,
      'confidence': confidence,
      'processing_time_ms': processingTimeMs,
      'metadata': _encodeMetadata(metadata),
      'device_info': deviceInfo,
      'app_version': appVersion,
    };
  }

  /// Crea modelo desde mapa de BD
  factory AnalysisEvent.fromMap(Map<String, dynamic> map) {
    return AnalysisEvent(
      id: map['id'],
      imagePath: map['image_path'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      analysisType: map['analysis_type'] ?? 'unknown',
      wasSuccessful: (map['was_successful'] ?? 0) == 1,
      identifiedPersonId: map['identified_person_id'],
      identifiedPersonName: map['identified_person_name'],
      confidence: map['confidence']?.toDouble(),
      processingTimeMs: map['processing_time_ms'] ?? 0,
      metadata: _decodeMetadata(map['metadata'] ?? '{}'),
      deviceInfo: map['device_info'] ?? 'unknown',
      appVersion: map['app_version'] ?? '1.0.0',
    );
  }

  /// Codifica metadatos a JSON string
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    try {
      return metadata.toString(); // Implementación simplificada
    } catch (e) {
      return '{}';
    }
  }

  /// Decodifica metadatos desde JSON string
  static Map<String, dynamic> _decodeMetadata(String jsonString) {
    try {
      // Implementación simplificada - en producción usar jsonDecode
      return <String, dynamic>{'raw': jsonString};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Crea evento para identificación exitosa
  factory AnalysisEvent.identification({
    required String imagePath,
    required int personId,
    required String personName,
    required double confidence,
    required int processingTime,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return AnalysisEvent(
      imagePath: imagePath,
      timestamp: DateTime.now(),
      analysisType: 'identification',
      wasSuccessful: true,
      identifiedPersonId: personId,
      identifiedPersonName: personName,
      confidence: confidence,
      processingTimeMs: processingTime,
      metadata: {
        'algorithm_version': '2.0',
        'threshold_used': 0.75,
        'features_extracted': ['landmarks', 'geometric', 'lbp', 'hog', 'frequency'],
        ...?additionalMetadata,
      },
      deviceInfo: _getDeviceInfo(),
      appVersion: '1.0.0',
    );
  }

  /// Crea evento para identificación fallida
  factory AnalysisEvent.identificationFailed({
    required String imagePath,
    required int processingTime,
    double? bestSimilarity,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return AnalysisEvent(
      imagePath: imagePath,
      timestamp: DateTime.now(),
      analysisType: 'identification',
      wasSuccessful: false,
      processingTimeMs: processingTime,
      metadata: {
        'algorithm_version': '2.0',
        'threshold_used': 0.75,
        'best_similarity': bestSimilarity,
        'reason': 'no_match_found',
        ...?additionalMetadata,
      },
      deviceInfo: _getDeviceInfo(),
      appVersion: '1.0.0',
    );
  }

  /// Crea evento para registro de nueva persona
  factory AnalysisEvent.registration({
    required String imagePath,
    required int personId,
    required String personName,
    required int processingTime,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return AnalysisEvent(
      imagePath: imagePath,
      timestamp: DateTime.now(),
      analysisType: 'registration',
      wasSuccessful: true,
      identifiedPersonId: personId,
      identifiedPersonName: personName,
      processingTimeMs: processingTime,
      metadata: {
        'algorithm_version': '2.0',
        'embedding_generated': true,
        'face_detected': true,
        ...?additionalMetadata,
      },
      deviceInfo: _getDeviceInfo(),
      appVersion: '1.0.0',
    );
  }

  /// Crea evento para scanner automático
  factory AnalysisEvent.scanner({
    required String imagePath,
    required bool wasSuccessful,
    int? personId,
    String? personName,
    double? confidence,
    required int processingTime,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return AnalysisEvent(
      imagePath: imagePath,
      timestamp: DateTime.now(),
      analysisType: 'scanner',
      wasSuccessful: wasSuccessful,
      identifiedPersonId: personId,
      identifiedPersonName: personName,
      confidence: confidence,
      processingTimeMs: processingTime,
      metadata: {
        'algorithm_version': '2.0',
        'scan_mode': 'realtime',
        'auto_capture': true,
        ...?additionalMetadata,
      },
      deviceInfo: _getDeviceInfo(),
      appVersion: '1.0.0',
    );
  }

  /// Obtiene información del dispositivo
  static String _getDeviceInfo() {
    // En implementación real usarías device_info_plus
    return 'Windows Desktop';
  }

  /// Convierte a string para debug
  @override
  String toString() {
    return 'AnalysisEvent(id: $id, type: $analysisType, success: $wasSuccessful, person: $identifiedPersonName, confidence: $confidence, time: ${processingTimeMs}ms)';
  }
}