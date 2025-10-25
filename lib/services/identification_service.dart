import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../models/person.dart';
import '../models/identification_event.dart';
import '../models/analysis_event.dart';
import '../utils/app_logger.dart';

import 'dart:math';
import 'dart:convert';

/// Servicio para realizar identificación 1:N contra la base de datos
class IdentificationService {
  static final IdentificationService _instance = IdentificationService._internal();
  factory IdentificationService() => _instance;
  IdentificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();

  /// Inicializa el servicio de identificación
  Future<bool> initialize() async {
    try {
      // Inicializar el servicio de embeddings
      await _embeddingService.initialize();
      return true;
    } catch (e) {
      BiometricLogger.error('Error inicializando IdentificationService', e);
      return false;
    }
  }

  /// Calcula el umbral óptimo basado en datos históricos
  Future<double> calculateOptimalThreshold() async {
    try {
      final events = await _dbService.getAllEvents(limit: 100);
      if (events.isEmpty) return 0.75; // Valor por defecto
      
      // Calcular umbral basado en confianza promedio de identificaciones exitosas
      final successfulEvents = events.where((e) => e.identified).toList();
      if (successfulEvents.isEmpty) return 0.75;
      
      final avgConfidence = successfulEvents
          .map((e) => e.confidence ?? 0.75)
          .reduce((a, b) => a + b) / successfulEvents.length;
      
      // Reducir ligeramente el umbral para permitir identificaciones válidas
      return (avgConfidence * 0.9).clamp(0.6, 0.9);
    } catch (e) {
      BiometricLogger.error('Error calculando umbral óptimo', e);
      return 0.75;
    }
  }

  /// Registra un evento de análisis externo
  Future<void> registerAnalysisEvent({
    required String imagePath,
    required String analysisType,
    required bool wasSuccessful,
    int? personId,
    String? personName,
    required double confidence,
    required int processingTimeMs,
    Map<String, dynamic>? metadata,
    String? documentId,
  }) async {
    await _saveAnalysisEvent(
      imagePath: imagePath,
      analysisType: analysisType,
      wasSuccessful: wasSuccessful,
      personId: personId,
      personName: personName,
      confidence: confidence,
      processingTimeMs: processingTimeMs,
      metadata: {
        ...?metadata,
        'source': 'external_registration',
        'document_id': documentId,
      },
    );
  }

  /// Getter para acceder al servicio de embeddings
  FaceEmbeddingService get faceEmbeddingService => _embeddingService;

  /// Identifica una persona comparando contra toda la base de datos
  Future<IdentificationResult> identifyPerson(
    String imagePath, {
    double threshold = 0.50, // Reducido para embeddings simulados
    int maxCandidates = 5,
    bool saveEvent = true,
  }) async {
    try {
      BiometricLogger.info('Iniciando identificación 1:N para: $imagePath');
      BiometricLogger.info('Umbral de confianza: ${(threshold * 100).toStringAsFixed(1)}%');
      
      // Generar embedding de la imagen capturada
      final queryEmbedding = await _embeddingService.generateEmbedding(imagePath);
      if (queryEmbedding == null || queryEmbedding.isEmpty) {
        BiometricLogger.warning('No se pudo generar embedding de la imagen');
        return IdentificationResult.error('No se pudo generar embedding de la imagen');
      }

      BiometricLogger.info('Embedding de consulta generado: ${queryEmbedding.length} dimensiones');

      // Obtener todas las personas registradas
      final allPersons = await _dbService.getAllPersons(limit: 1000);
      if (allPersons.isEmpty) {
        BiometricLogger.warning('No hay personas registradas en el sistema');
        return IdentificationResult.noMatch('No hay personas registradas en el sistema');
      }

      BiometricLogger.info('Comparando contra ${allPersons.length} personas registradas');

      // Realizar comparación 1:N con validaciones múltiples
      final comparisonResults = <PersonSimilarity>[];

      for (final person in allPersons) {
        try {
          // Convertir embedding almacenado a lista de double
          final storedEmbedding = _parseEmbeddingFromJson(person.embedding);

          // VALIDACIÓN 1: Verificar calidad de embeddings (reducido para compatibilidad)
          if (queryEmbedding.length < 128 || storedEmbedding.length < 128) {
            BiometricLogger.debug('Embedding insuficiente para ${person.name}: query=${queryEmbedding.length}, stored=${storedEmbedding.length}');
            continue;
          }

          // VALIDACIÓN 2: Calcular múltiples métricas de similitud
          final cosineSimilarity = _calculateCosineSimilarity(queryEmbedding, storedEmbedding);
          final euclideanSimilarity = _calculateEuclideanSimilarity(queryEmbedding, storedEmbedding);
          final manhattanSimilarity = _calculateManhattanSimilarity(queryEmbedding, storedEmbedding);

          // VALIDACIÓN 3: Combinar métricas con pesos optimizados
          final combinedSimilarity = (cosineSimilarity * 0.7) +  // Mayor peso a coseno
                                   (euclideanSimilarity * 0.2) + 
                                   (manhattanSimilarity * 0.1);

          // VALIDACIÓN 4: Verificar consistencia entre métricas
          final maxDiff = [cosineSimilarity, euclideanSimilarity, manhattanSimilarity]
              .fold(0.0, (max, val) => max > val ? max : val) -
              [cosineSimilarity, euclideanSimilarity, manhattanSimilarity]
              .fold(1.0, (min, val) => min < val ? min : val);

          // Si las métricas difieren mucho, es sospechoso
          final isConsistent = maxDiff < 0.4; // Aumentado de 0.3 para ser menos estricto
          final finalConfidence = isConsistent ? combinedSimilarity : combinedSimilarity * 0.85;

          comparisonResults.add(PersonSimilarity(
            person: person,
            similarity: combinedSimilarity,
            confidence: finalConfidence,
          ));

          BiometricLogger.debug('${person.name}: '
              'cosine=${(cosineSimilarity * 100).toStringAsFixed(1)}%, '
              'euclidean=${(euclideanSimilarity * 100).toStringAsFixed(1)}%, '
              'manhattan=${(manhattanSimilarity * 100).toStringAsFixed(1)}%, '
              'combined=${(combinedSimilarity * 100).toStringAsFixed(1)}%, '
              'final=${(finalConfidence * 100).toStringAsFixed(1)}% '
              '(consistent=$isConsistent, maxDiff=${(maxDiff * 100).toStringAsFixed(1)}%)');

        } catch (e) {
          BiometricLogger.error('Error procesando persona ${person.name}', e);
          continue;
        }
      }

      // Ordenar resultados por confianza (descendente)
      comparisonResults.sort((a, b) => b.confidence.compareTo(a.confidence));

      IdentificationResult result;
      final bestMatch = comparisonResults.isNotEmpty ? comparisonResults.first : null;

      // Log detallado de resultados
      if (comparisonResults.isNotEmpty) {
        BiometricLogger.info('Top 3 candidatos:');
        for (int i = 0; i < comparisonResults.length && i < 3; i++) {
          final candidate = comparisonResults[i];
          BiometricLogger.info('  ${i + 1}. ${candidate.person.name}: ${(candidate.confidence * 100).toStringAsFixed(1)}%');
        }
      }

      if (bestMatch != null && bestMatch.confidence >= threshold) {
        // Persona identificada exitosamente
        result = IdentificationResult.identified(
          bestMatch.person,
          confidence: bestMatch.confidence,
          allCandidates: comparisonResults.take(maxCandidates).toList(),
        );

        BiometricLogger.info('Persona IDENTIFICADA: ${bestMatch.person.name} con ${(bestMatch.confidence * 100).toStringAsFixed(1)}% de confianza (umbral: ${(threshold * 100).toStringAsFixed(1)}%)');
      } else {
        // Persona no identificada
        result = IdentificationResult.noMatch(
          'No se encontró coincidencia suficiente',
          bestCandidate: bestMatch,
          allCandidates: comparisonResults.take(maxCandidates).toList(),
        );

        final bestConfidence = bestMatch?.confidence ?? 0.0;
        BiometricLogger.warning('Persona NO IDENTIFICADA. Mejor candidato: ${bestMatch?.person.name ?? "ninguno"} con ${(bestConfidence * 100).toStringAsFixed(1)}% (umbral requerido: ${(threshold * 100).toStringAsFixed(1)}%)');
      }

      // Guardar eventos (tanto el tradicional como el detallado)
      if (saveEvent) {
        // Evento tradicional (compatibilidad)
        await _saveIdentificationEvent(result, imagePath);
        
        // Evento de análisis detallado (nuevo)
        await _saveAnalysisEvent(
          imagePath: imagePath,
          analysisType: 'identification_1n',
          wasSuccessful: result.isIdentified,
          personId: result.person?.id,
          personName: result.person?.name,
          confidence: result.confidence ?? 0.0,
          processingTimeMs: 0, // Se calcularía en implementación real
          metadata: {
            'candidatesCount': comparisonResults.length,
            'threshold': threshold,
            'bestSimilarity': bestMatch?.similarity ?? 0.0,
          },
        );
      }

      return result;

    } catch (e, stackTrace) {
      BiometricLogger.error('Error en identificación', e, stackTrace);
      return IdentificationResult.error('Error interno: ${e.toString()}');
    }
  }

  /// Guarda un evento de identificación tradicional
  Future<void> _saveIdentificationEvent(IdentificationResult result, String imagePath) async {
    try {
          final event = IdentificationEvent(
        identified: result.isIdentified,
        personId: result.person?.id,
        personName: result.person?.name ?? 'Desconocido',
        confidence: result.confidence ?? 0.0,
        timestamp: DateTime.now(),
      );      await _dbService.insertIdentificationEvent(event);
      
      BiometricLogger.info('Evento de identificación guardado: ${result.isIdentified ? "Identificado" : "No identificado"}');
    } catch (e) {
      BiometricLogger.error('Error guardando evento de identificación', e);
    }
  }

  /// Guarda un evento de análisis detallado
  Future<void> _saveAnalysisEvent({
    required String imagePath,
    required String analysisType,
    required bool wasSuccessful,
    int? personId,
    String? personName,
    required double confidence,
    required int processingTimeMs,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final event = AnalysisEvent(
        imagePath: imagePath,
        analysisType: analysisType,
        wasSuccessful: wasSuccessful,
        identifiedPersonId: personId,
        identifiedPersonName: personName,
        confidence: confidence,
        processingTimeMs: processingTimeMs,
        timestamp: DateTime.now(),
        metadata: {
          ...?metadata,
          'timestamp': DateTime.now().toIso8601String(),
        },
        deviceInfo: 'Android', // Simplificado por ahora
        appVersion: '1.0.0',   // Simplificado por ahora
      );

      await _dbService.insertAnalysisEvent(event);
      
      BiometricLogger.info('Evento de análisis registrado: $analysisType - ${processingTimeMs}ms - ${event.wasSuccessful ? "Exitoso" : "Fallido"}');
    } catch (e) {
      BiometricLogger.error('Error registrando evento de análisis', e);
    }
  }

  /// Obtiene estadísticas de identificación
  Future<IdentificationStats> getIdentificationStats() async {
    try {
      final totalEvents = await _dbService.getEventsCount();
      final allEvents = await _dbService.getAllEvents(limit: 1000);

      int identifiedCount = 0;
      int unknownCount = 0;
      double totalConfidence = 0.0;
      DateTime? lastEvent;

      for (final event in allEvents) {
        if (event.identified) {
          identifiedCount++;
          totalConfidence += event.confidence ?? 0.0;
        } else {
          unknownCount++;
        }

        if (lastEvent == null || event.timestamp.isAfter(lastEvent)) {
          lastEvent = event.timestamp;
        }
      }

      final identificationRate = totalEvents > 0 ? identifiedCount / totalEvents : 0.0;
      final averageConfidence = identifiedCount > 0 ? totalConfidence / identifiedCount : 0.0;

      return IdentificationStats(
        totalEvents: totalEvents,
        identifiedCount: identifiedCount,
        unknownCount: unknownCount,
        identificationRate: identificationRate,
        averageConfidence: averageConfidence,
        lastEventTime: lastEvent,
      );

    } catch (e) {
      BiometricLogger.error('Error obteniendo estadísticas', e);
      return IdentificationStats.empty();
    }
  }

  // ==================== MÉTODOS DE SIMILITUD ADICIONALES ====================

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

  /// Calcula similitud euclidiana normalizada
  double _calculateEuclideanSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double sumSquaredDiff = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      final diff = embedding1[i] - embedding2[i];
      sumSquaredDiff += diff * diff;
    }

    final euclideanDistance = sqrt(sumSquaredDiff);
    // Normalizar: convertir distancia a similitud (0-1)
    return 1.0 / (1.0 + euclideanDistance);
  }

  /// Calcula similitud Manhattan normalizada
  double _calculateManhattanSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double sumAbsDiff = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      sumAbsDiff += (embedding1[i] - embedding2[i]).abs();
    }

    final manhattanDistance = sumAbsDiff / embedding1.length;
    // Normalizar: convertir distancia a similitud (0-1)
    return 1.0 / (1.0 + manhattanDistance);
  }

  /// Parsea un embedding desde JSON string a List<double> con validación de seguridad
  List<double> _parseEmbeddingFromJson(String embeddingJson) {
    try {
      // Validación de seguridad: verificar que no sea null o vacío
      if (embeddingJson.isEmpty) {
        BiometricLogger.warning('Intento de parsear embedding vacío');
        return List.filled(512, 0.0);
      }

      List<double> result;
      
      // Si es una lista JSON simple
      if (embeddingJson.startsWith('[')) {
        try {
          final List<dynamic> parsed = jsonDecode(embeddingJson);
          result = parsed.map((e) => (e as num).toDouble()).toList();
        } catch (e) {
          // Fallback a parsing manual
          BiometricLogger.debug('Error con jsonDecode, usando parsing manual: $e');
          final cleanString = embeddingJson
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          result = cleanString
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .map((e) => double.tryParse(e.trim()) ?? 0.0)
              .toList();
        }
      } else {
        // Si son valores separados por coma (legacy)
        result = embeddingJson
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .map((e) => double.tryParse(e.trim()) ?? 0.0)
            .toList();
      }
      
      // Validación de dimensiones
      if (result.isEmpty) {
        BiometricLogger.warning('Embedding parseado está vacío');
        return List.filled(512, 0.0);
      }
      
      if (result.length < 256) {
        BiometricLogger.debug('Embedding con dimensiones insuficientes: ${result.length}');
      }
      
      return result;
    } catch (e) {
      BiometricLogger.error('Error parsing embedding', e);
      return List.filled(512, 0.0); // Fallback seguro
    }
  }
}

/// Resultado de una operación de identificación 1:N
class IdentificationResult {
  final bool isIdentified;
  final Person? person;
  final double? confidence;
  final String? errorMessage;
  final String? noMatchReason;
  final PersonSimilarity? bestCandidate;
  final List<PersonSimilarity>? allCandidates;

  IdentificationResult._({
    required this.isIdentified,
    this.person,
    this.confidence,
    this.errorMessage,
    this.noMatchReason,
    this.bestCandidate,
    this.allCandidates,
  });

  /// Constructor para identificación exitosa
  factory IdentificationResult.identified(
    Person person, {
    required double confidence,
    List<PersonSimilarity>? allCandidates,
  }) {
    return IdentificationResult._(
      isIdentified: true,
      person: person,
      confidence: confidence,
      allCandidates: allCandidates,
    );
  }

  /// Constructor para no identificación
  factory IdentificationResult.noMatch(
    String reason, {
    PersonSimilarity? bestCandidate,
    List<PersonSimilarity>? allCandidates,
  }) {
    return IdentificationResult._(
      isIdentified: false,
      noMatchReason: reason,
      bestCandidate: bestCandidate,
      allCandidates: allCandidates,
    );
  }

  /// Constructor para error
  factory IdentificationResult.error(String errorMessage) {
    return IdentificationResult._(
      isIdentified: false,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isError => hasError;
  bool get hasNoMatch => !isIdentified && !hasError;
  
  String get statusMessage => displayMessage;
  
  String get displayMessage {
    if (hasError) return errorMessage!;
    if (isIdentified) return 'Identificado: ${person!.name}';
    return noMatchReason ?? 'No identificado';
  }
}

/// Representa la similitud entre una consulta y una persona registrada
class PersonSimilarity {
  final Person person;
  final double similarity;
  final double confidence;

  PersonSimilarity({
    required this.person,
    required this.similarity,
    required this.confidence,
  });

  /// Getter para obtener la similitud como porcentaje
  double get similarityPercent => similarity * 100;

  @override
  String toString() {
    return '${person.name}: ${(confidence * 100).toStringAsFixed(1)}%';
  }
}

/// Estadísticas de identificación del sistema
class IdentificationStats {
  final int totalEvents;
  final int identifiedCount;
  final int unknownCount;
  final double identificationRate;
  final double averageConfidence;
  final DateTime? lastEventTime;

  IdentificationStats({
    required this.totalEvents,
    required this.identifiedCount,
    required this.unknownCount,
    required this.identificationRate,
    required this.averageConfidence,
    this.lastEventTime,
  });

  factory IdentificationStats.empty() {
    return IdentificationStats(
      totalEvents: 0,
      identifiedCount: 0,
      unknownCount: 0,
      identificationRate: 0.0,
      averageConfidence: 0.0,
    );
  }

  double get identificationRatePercent => identificationRate * 100;
  double get averageConfidencePercent => averageConfidence * 100;
}