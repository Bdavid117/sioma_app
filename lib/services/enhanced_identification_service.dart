import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../services/face_detection_service.dart';
import '../models/person.dart';
import '../utils/app_logger.dart';

import 'dart:math';
import 'dart:convert';

/// Servicio MEJORADO de identificación con ML Kit Face Detection
/// Mejora la precisión del reconocimiento facial mediante:
/// 1. Pre-validación de calidad facial con ML Kit
/// 2. Filtrado de personas candidatas por características faciales
/// 3. Comparación inteligente de embeddings con múltiples métricas
/// 4. Sistema adaptativo de umbrales
class EnhancedIdentificationService {
  static final EnhancedIdentificationService _instance = EnhancedIdentificationService._internal();
  factory EnhancedIdentificationService() => _instance;
  EnhancedIdentificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final FaceDetectionService _faceDetection = FaceDetectionService();

  /// Inicializa el servicio de identificación mejorado
  Future<bool> initialize() async {
    try {
      await _embeddingService.initialize();
      AppLogger.info('✅ EnhancedIdentificationService inicializado');
      return true;
    } catch (e) {
      AppLogger.error('Error inicializando EnhancedIdentificationService', error: e);
      return false;
    }
  }

  /// NUEVA FUNCIÓN: Identifica persona con validación ML Kit
  Future<EnhancedIdentificationResult> identifyPersonWithMLKit(
    String imagePath, {
    double threshold = 0.65,
    int maxCandidates = 5,
    bool strictMode = false, // Modo estricto requiere mayor calidad
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info('🔍 Iniciando identificación MEJORADA con ML Kit');
      AppLogger.info('📊 Umbral: ${(threshold * 100).toStringAsFixed(1)}%, Modo estricto: $strictMode');

      // ========================================
      // PASO 1: PRE-VALIDACIÓN CON ML KIT
      // ========================================
      AppLogger.info('PASO 1/5: Validando calidad facial con ML Kit...');
      final faceDetectionResult = await _faceDetection.detectFaces(imagePath);

      if (!faceDetectionResult.success) {
        return EnhancedIdentificationResult.error(
          faceDetectionResult.errorMessage ?? 'No se detectó ningún rostro',
          mlKitValidation: faceDetectionResult,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      if (!faceDetectionResult.hasOneFace) {
        return EnhancedIdentificationResult.error(
          'Se detectaron ${faceDetectionResult.faceCount} rostros. Se requiere solo uno.',
          mlKitValidation: faceDetectionResult,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Validar calidad mínima
      final qualityScore = faceDetectionResult.analysis?.qualityScore ?? 0.0;
      final minQuality = strictMode ? 0.75 : 0.60;

      if (qualityScore < minQuality) {
        return EnhancedIdentificationResult.error(
          'Calidad facial insuficiente: ${(qualityScore * 100).toStringAsFixed(1)}% (mínimo: ${(minQuality * 100).toStringAsFixed(1)}%)',
          mlKitValidation: faceDetectionResult,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          recommendations: faceDetectionResult.recommendations,
        );
      }

      AppLogger.info('✅ Rostro validado - Calidad: ${(qualityScore * 100).toStringAsFixed(1)}%');

      // ========================================
      // PASO 2: GENERAR EMBEDDING
      // ========================================
      AppLogger.info('PASO 2/5: Generando embedding facial...');
      final queryEmbedding = await _embeddingService.generateEmbedding(imagePath);

      if (queryEmbedding == null || queryEmbedding.isEmpty) {
        return EnhancedIdentificationResult.error(
          'No se pudo generar embedding facial',
          mlKitValidation: faceDetectionResult,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      AppLogger.info('✅ Embedding generado: ${queryEmbedding.length}D');

      // ========================================
      // PASO 3: OBTENER PERSONAS REGISTRADAS
      // ========================================
      AppLogger.info('PASO 3/5: Obteniendo personas registradas...');
      final allPersons = await _dbService.getAllPersons(limit: 1000);

      if (allPersons.isEmpty) {
        return EnhancedIdentificationResult.error(
          'No hay personas registradas en el sistema',
          mlKitValidation: faceDetectionResult,
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      AppLogger.info('👥 Comparando contra ${allPersons.length} personas');

      // ========================================
      // PASO 4: COMPARACIÓN INTELIGENTE 1:N
      // ========================================
      AppLogger.info('PASO 4/5: Realizando comparación 1:N mejorada...');
      final comparisonResults = <EnhancedPersonMatch>[];

      for (final person in allPersons) {
        try {
          final match = await _compareWithPerson(
            person: person,
            queryEmbedding: queryEmbedding,
            queryFaceAnalysis: faceDetectionResult.analysis!,
            strictMode: strictMode,
          );

          if (match != null) {
            comparisonResults.add(match);
          }
        } catch (e) {
          AppLogger.error('Error comparando con ${person.name}', error: e);
        }
      }

      // Ordenar por confianza ajustada (descendente)
      comparisonResults.sort((a, b) => b.adjustedConfidence.compareTo(a.adjustedConfidence));

      // Log top 3 candidatos
      AppLogger.info('Top candidatos:');
      for (int i = 0; i < comparisonResults.length && i < 3; i++) {
        final match = comparisonResults[i];
        AppLogger.info('  ${i + 1}. ${match.person.name}: ${(match.adjustedConfidence * 100).toStringAsFixed(1)}% '
            '(base: ${(match.baseConfidence * 100).toStringAsFixed(1)}%, '
            'boost: ${match.mlKitBoost > 0 ? "+${(match.mlKitBoost * 100).toStringAsFixed(1)}%" : "0%"})');
      }

      // ========================================
      // PASO 5: DETERMINAR RESULTADO FINAL
      // ========================================
      AppLogger.info('PASO 5/5: Determinando resultado final...');
      final bestMatch = comparisonResults.isNotEmpty ? comparisonResults.first : null;

      final result = _buildFinalResult(
        bestMatch: bestMatch,
        allMatches: comparisonResults,
        threshold: threshold,
        maxCandidates: maxCandidates,
        mlKitValidation: faceDetectionResult,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );

      stopwatch.stop();
      AppLogger.info('⏱️ Identificación completada en ${stopwatch.elapsedMilliseconds}ms');

      return result;

    } catch (e) {
      stopwatch.stop();
      AppLogger.error('Error en identificación mejorada', error: e);
      return EnhancedIdentificationResult.error(
        'Error inesperado: $e',
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Compara embedding con una persona específica usando ML Kit
  Future<EnhancedPersonMatch?> _compareWithPerson({
    required Person person,
    required List<double> queryEmbedding,
    required FaceQualityAnalysis queryFaceAnalysis,
    required bool strictMode,
  }) async {
    try {
      // Parsear embedding almacenado
      final storedEmbedding = _parseEmbeddingFromJson(person.embedding);

      if (queryEmbedding.length < 100 || storedEmbedding.length < 100) {
        return null; // Embedding insuficiente
      }

      // Calcular similitudes con múltiples métricas
      final cosineSim = _calculateCosineSimilarity(queryEmbedding, storedEmbedding);
      final euclideanSim = _calculateEuclideanSimilarity(queryEmbedding, storedEmbedding);
      final manhattanSim = _calculateManhattanSimilarity(queryEmbedding, storedEmbedding);

      // Confianza base combinada
      final baseConfidence = (cosineSim * 0.65) + (euclideanSim * 0.25) + (manhattanSim * 0.10);

      // NUEVA MEJORA: Boost basado en características faciales ML Kit
      double mlKitBoost = 0.0;

      // Si tenemos metadata de la persona registrada, compararla
      if (person.metadata != null && person.metadata!.isNotEmpty) {
        mlKitBoost = _calculateMLKitBoost(
          queryAnalysis: queryFaceAnalysis,
          storedMetadata: person.metadata!,
        );
      }

      // Confianza ajustada con boost ML Kit
      final adjustedConfidence = (baseConfidence + mlKitBoost).clamp(0.0, 1.0);

      // Verificar consistencia entre métricas
      final similarities = [cosineSim, euclideanSim, manhattanSim];
      final maxDiff = similarities.reduce((a, b) => a > b ? a : b) - 
                      similarities.reduce((a, b) => a < b ? a : b);
      final isConsistent = maxDiff < 0.45;

      // Penalizar si no es consistente
      final finalConfidence = isConsistent ? adjustedConfidence : adjustedConfidence * 0.90;

      return EnhancedPersonMatch(
        person: person,
        baseConfidence: baseConfidence,
        adjustedConfidence: finalConfidence,
        cosineSimilarity: cosineSim,
        euclideanSimilarity: euclideanSim,
        manhattanSimilarity: manhattanSim,
        mlKitBoost: mlKitBoost,
        isConsistent: isConsistent,
        metricsVariance: maxDiff,
      );

    } catch (e) {
      AppLogger.error('Error en _compareWithPerson para ${person.name}', error: e);
      return null;
    }
  }

  /// NUEVA FUNCIÓN: Calcula boost de confianza basado en características faciales
  double _calculateMLKitBoost({
    required FaceQualityAnalysis queryAnalysis,
    required Map<String, dynamic> storedMetadata,
  }) {
    double boost = 0.0;
    int matchedFeatures = 0;

    try {
      // Comparar ángulo de cabeza (±15 grados de tolerancia)
      if (storedMetadata.containsKey('headAngle')) {
        final storedAngle = (storedMetadata['headAngle'] as num).toDouble();
        final queryAngle = queryAnalysis.headAngle;
        final angleDiff = (storedAngle - queryAngle).abs();

        if (angleDiff < 15) {
          boost += 0.03; // +3% si el ángulo es similar
          matchedFeatures++;
        }
      }

      // Comparar si está sonriendo (tolerancia ±0.2)
      if (storedMetadata.containsKey('smiling')) {
        final storedSmile = (storedMetadata['smiling'] as num).toDouble();
        final querySmile = queryAnalysis.smiling;
        final smileDiff = (storedSmile - querySmile).abs();

        if (smileDiff < 0.3) {
          boost += 0.02; // +2% si sonrisa similar
          matchedFeatures++;
        }
      }

      // Comparar estado de ojos
      if (storedMetadata.containsKey('leftEyeOpen') && storedMetadata.containsKey('rightEyeOpen')) {
        final storedLeftEye = (storedMetadata['leftEyeOpen'] as num).toDouble();
        final storedRightEye = (storedMetadata['rightEyeOpen'] as num).toDouble();
        final queryLeftEye = queryAnalysis.leftEyeOpen;
        final queryRightEye = queryAnalysis.rightEyeOpen;

        // Si ambos ojos están abiertos en ambas imágenes
        if (storedLeftEye > 0.5 && storedRightEye > 0.5 && 
            queryLeftEye > 0.5 && queryRightEye > 0.5) {
          boost += 0.03; // +3% si ambos tienen ojos abiertos
          matchedFeatures++;
        }
      }

      // Bonus adicional si se matchearon múltiples características
      if (matchedFeatures >= 2) {
        boost += 0.02; // +2% bonus por múltiples coincidencias
      }

      AppLogger.debug('ML Kit Boost: +${(boost * 100).toStringAsFixed(1)}% (matched features: $matchedFeatures)');

    } catch (e) {
      AppLogger.error('Error calculando ML Kit boost', error: e);
    }

    return boost.clamp(0.0, 0.10); // Máximo 10% de boost
  }

  /// Construye el resultado final de identificación
  EnhancedIdentificationResult _buildFinalResult({
    required EnhancedPersonMatch? bestMatch,
    required List<EnhancedPersonMatch> allMatches,
    required double threshold,
    required int maxCandidates,
    required FaceDetectionResult mlKitValidation,
    required int processingTimeMs,
  }) {
    if (bestMatch != null && bestMatch.adjustedConfidence >= threshold) {
      // IDENTIFICACIÓN EXITOSA
      AppLogger.info('✅ IDENTIFICADO: ${bestMatch.person.name} - ${(bestMatch.adjustedConfidence * 100).toStringAsFixed(1)}%');

      return EnhancedIdentificationResult.identified(
        person: bestMatch.person,
        confidence: bestMatch.adjustedConfidence,
        baseConfidence: bestMatch.baseConfidence,
        mlKitBoost: bestMatch.mlKitBoost,
        mlKitValidation: mlKitValidation,
        allCandidates: allMatches.take(maxCandidates).toList(),
        processingTimeMs: processingTimeMs,
      );
    } else {
      // NO IDENTIFICADO
      final bestConfidence = bestMatch?.adjustedConfidence ?? 0.0;
      AppLogger.warning('❌ NO IDENTIFICADO - Mejor: ${bestMatch?.person.name ?? "ninguno"} (${(bestConfidence * 100).toStringAsFixed(1)}%)');

      return EnhancedIdentificationResult.noMatch(
        message: 'No se encontró coincidencia suficiente',
        bestCandidate: bestMatch,
        allCandidates: allMatches.take(maxCandidates).toList(),
        mlKitValidation: mlKitValidation,
        processingTimeMs: processingTimeMs,
      );
    }
  }

  // ==========================================
  // FUNCIONES AUXILIARES
  // ==========================================

  List<double> _parseEmbeddingFromJson(String embeddingJson) {
    try {
      final decoded = jsonDecode(embeddingJson);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error parseando embedding', error: e);
      return [];
    }
  }

  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    final similarity = dotProduct / (sqrt(normA) * sqrt(normB));
    return ((similarity + 1) / 2).clamp(0.0, 1.0); // Normalizar a [0, 1]
  }

  double _calculateEuclideanSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double sumSquares = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sumSquares += diff * diff;
    }

    final distance = sqrt(sumSquares);
    return 1.0 / (1.0 + distance); // Convertir distancia a similitud
  }

  double _calculateManhattanSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double sumDiff = 0.0;
    for (int i = 0; i < a.length; i++) {
      sumDiff += (a[i] - b[i]).abs();
    }

    return 1.0 / (1.0 + sumDiff / a.length);
  }
}

// ==========================================
// MODELOS DE DATOS MEJORADOS
// ==========================================

/// Match mejorado con información de ML Kit
class EnhancedPersonMatch {
  final Person person;
  final double baseConfidence;
  final double adjustedConfidence;
  final double cosineSimilarity;
  final double euclideanSimilarity;
  final double manhattanSimilarity;
  final double mlKitBoost;
  final bool isConsistent;
  final double metricsVariance;

  EnhancedPersonMatch({
    required this.person,
    required this.baseConfidence,
    required this.adjustedConfidence,
    required this.cosineSimilarity,
    required this.euclideanSimilarity,
    required this.manhattanSimilarity,
    required this.mlKitBoost,
    required this.isConsistent,
    required this.metricsVariance,
  });
}

/// Resultado mejorado de identificación
class EnhancedIdentificationResult {
  final bool success;
  final bool identified;
  final Person? person;
  final double? confidence;
  final double? baseConfidence;
  final double? mlKitBoost;
  final String message;
  final FaceDetectionResult? mlKitValidation;
  final EnhancedPersonMatch? bestCandidate;
  final List<EnhancedPersonMatch> allCandidates;
  final int processingTimeMs;
  final List<String> recommendations;

  EnhancedIdentificationResult({
    required this.success,
    required this.identified,
    this.person,
    this.confidence,
    this.baseConfidence,
    this.mlKitBoost,
    required this.message,
    this.mlKitValidation,
    this.bestCandidate,
    this.allCandidates = const [],
    required this.processingTimeMs,
    this.recommendations = const [],
  });

  factory EnhancedIdentificationResult.identified({
    required Person person,
    required double confidence,
    required double baseConfidence,
    required double mlKitBoost,
    required FaceDetectionResult mlKitValidation,
    required List<EnhancedPersonMatch> allCandidates,
    required int processingTimeMs,
  }) {
    return EnhancedIdentificationResult(
      success: true,
      identified: true,
      person: person,
      confidence: confidence,
      baseConfidence: baseConfidence,
      mlKitBoost: mlKitBoost,
      message: '✅ Persona identificada: ${person.name}',
      mlKitValidation: mlKitValidation,
      allCandidates: allCandidates,
      processingTimeMs: processingTimeMs,
    );
  }

  factory EnhancedIdentificationResult.noMatch({
    required String message,
    EnhancedPersonMatch? bestCandidate,
    List<EnhancedPersonMatch> allCandidates = const [],
    FaceDetectionResult? mlKitValidation,
    required int processingTimeMs,
  }) {
    return EnhancedIdentificationResult(
      success: true,
      identified: false,
      message: message,
      bestCandidate: bestCandidate,
      allCandidates: allCandidates,
      mlKitValidation: mlKitValidation,
      processingTimeMs: processingTimeMs,
    );
  }

  factory EnhancedIdentificationResult.error(
    String message, {
    FaceDetectionResult? mlKitValidation,
    required int processingTimeMs,
    List<String> recommendations = const [],
  }) {
    return EnhancedIdentificationResult(
      success: false,
      identified: false,
      message: message,
      mlKitValidation: mlKitValidation,
      processingTimeMs: processingTimeMs,
      recommendations: recommendations,
    );
  }

  /// Calidad facial según ML Kit
  double get faceQuality => mlKitValidation?.analysis?.qualityScore ?? 0.0;

  /// Porcentaje de mejora con ML Kit
  double get improvementPercentage {
    if (baseConfidence == null || mlKitBoost == null || baseConfidence == 0) return 0.0;
    return (mlKitBoost! / baseConfidence!) * 100;
  }
}
