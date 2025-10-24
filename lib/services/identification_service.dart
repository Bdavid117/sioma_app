import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../models/person.dart';
import '../models/identification_event.dart';
import '../utils/validation_utils.dart';
import 'dart:convert';
import 'dart:developer' as developer;

/// Servicio para realizar identificación 1:N contra la base de datos
class IdentificationService {
  static final IdentificationService _instance = IdentificationService._internal();
  factory IdentificationService() => _instance;
  IdentificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();

  // Configuración de identificación
  static const double defaultThreshold = 0.7; // 70% de similitud mínima
  static const int maxCandidates = 10; // Máximo de candidatos a evaluar

  /// Inicializa el servicio de identificación
  Future<bool> initialize() async {
    try {
      await _embeddingService.initialize();
      developer.log('IdentificationService initialized successfully');
      return true;
    } catch (e) {
      developer.log('Error initializing IdentificationService: $e', level: 1000);
      return false;
    }
  }

  /// Realiza identificación 1:N contra todas las personas registradas
  Future<IdentificationResult> identifyPerson(
    String imagePath, {
    double threshold = defaultThreshold,
    bool saveEvent = true,
  }) async {
    try {
      developer.log('Starting 1:N identification for image: $imagePath');

      // Validar imagen de entrada
      final pathValidation = ValidationUtils.validateFilePath(imagePath);
      if (!pathValidation.isValid) {
        return IdentificationResult.error('Ruta de imagen inválida: ${pathValidation.error}');
      }

      // Generar embedding de la imagen de consulta
      final queryEmbedding = await _embeddingService.generateEmbedding(imagePath);
      if (queryEmbedding == null) {
        return IdentificationResult.error('No se pudo generar embedding de la imagen');
      }

      developer.log('Query embedding generated: ${queryEmbedding.length}D');

      // Obtener todas las personas registradas
      final allPersons = await _dbService.getAllPersons(limit: 1000);
      if (allPersons.isEmpty) {
        return IdentificationResult.noMatch('No hay personas registradas en el sistema');
      }

      developer.log('Comparing against ${allPersons.length} registered persons');

      // Realizar comparación 1:N
      final comparisonResults = <PersonSimilarity>[];

      for (final person in allPersons) {
        try {
          // Convertir embedding almacenado a lista de double
          final storedEmbedding = _embeddingService.embeddingFromJson(person.embedding);

          // Calcular similitud
          final similarity = _embeddingService.calculateSimilarity(queryEmbedding, storedEmbedding);

          comparisonResults.add(PersonSimilarity(
            person: person,
            similarity: similarity,
            confidence: similarity,
          ));

          developer.log('Person ${person.name}: similarity = ${(similarity * 100).toStringAsFixed(1)}%');
        } catch (e) {
          developer.log('Error comparing with person ${person.name}: $e', level: 1000);
          continue;
        }
      }

      // Ordenar resultados por similitud descendente
      comparisonResults.sort((a, b) => b.similarity.compareTo(a.similarity));

      // Determinar mejor coincidencia
      final bestMatch = comparisonResults.isNotEmpty ? comparisonResults.first : null;

      IdentificationResult result;

      if (bestMatch != null && bestMatch.similarity >= threshold) {
        // Persona identificada
        result = IdentificationResult.identified(
          person: bestMatch.person,
          confidence: bestMatch.similarity,
          allCandidates: comparisonResults.take(maxCandidates).toList(),
        );

        developer.log('Person IDENTIFIED: ${bestMatch.person.name} with ${(bestMatch.similarity * 100).toStringAsFixed(1)}% confidence');
      } else {
        // Persona no identificada
        result = IdentificationResult.noMatch(
          'No se encontró coincidencia suficiente',
          bestCandidate: bestMatch,
          allCandidates: comparisonResults.take(maxCandidates).toList(),
        );

        developer.log('Person NOT IDENTIFIED. Best candidate: ${bestMatch?.similarity ?? 0 * 100}% (threshold: ${threshold * 100}%)');
      }

      // Guardar evento de identificación si está habilitado
      if (saveEvent) {
        await _saveIdentificationEvent(result, imagePath);
      }

      return result;
    } catch (e) {
      developer.log('Error during identification: $e', level: 1000);
      return IdentificationResult.error('Error durante la identificación: $e');
    }
  }

  /// Guarda el evento de identificación en la base de datos
  Future<void> _saveIdentificationEvent(IdentificationResult result, String imagePath) async {
    try {
      final event = IdentificationEvent(
        personId: result.isIdentified ? result.person?.id : null,
        personName: result.isIdentified ? result.person?.name : 'Desconocido',
        confidence: result.confidence,
        photoPath: imagePath,
        identified: result.isIdentified,
      );

      await _dbService.insertIdentificationEvent(event);
      developer.log('Identification event saved: ${result.isIdentified ? "IDENTIFIED" : "UNKNOWN"}');
    } catch (e) {
      developer.log('Error saving identification event: $e', level: 1000);
    }
  }

  /// Realiza identificación continua (modo streaming)
  Stream<IdentificationResult> identifyStream(
    Stream<String> imagePathStream, {
    double threshold = defaultThreshold,
    Duration debounceTime = const Duration(milliseconds: 1000),
  }) async* {
    DateTime lastProcessTime = DateTime.now();

    await for (final imagePath in imagePathStream) {
      final now = DateTime.now();

      // Debounce para evitar procesamiento excesivo
      if (now.difference(lastProcessTime) < debounceTime) {
        continue;
      }

      lastProcessTime = now;

      final result = await identifyPerson(imagePath, threshold: threshold, saveEvent: false);
      yield result;
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

      final avgConfidence = identifiedCount > 0 ? totalConfidence / identifiedCount : 0.0;

      return IdentificationStats(
        totalEvents: totalEvents,
        identifiedCount: identifiedCount,
        unknownCount: unknownCount,
        identificationRate: totalEvents > 0 ? identifiedCount / totalEvents : 0.0,
        averageConfidence: avgConfidence,
        lastEventTime: lastEvent,
      );
    } catch (e) {
      developer.log('Error getting identification stats: $e', level: 1000);
      return IdentificationStats.empty();
    }
  }

  /// Ajusta el threshold dinámicamente basado en el historial
  Future<double> calculateOptimalThreshold() async {
    try {
      final events = await _dbService.getAllEvents(limit: 500);
      final identifiedEvents = events.where((e) => e.identified && e.confidence != null).toList();

      if (identifiedEvents.length < 10) {
        return defaultThreshold; // Usar threshold por defecto si hay pocos datos
      }

      // Calcular threshold óptimo basado en percentil 25 de identificaciones exitosas
      final confidences = identifiedEvents.map((e) => e.confidence!).toList()..sort();
      final percentile25Index = (confidences.length * 0.25).floor();

      final optimalThreshold = confidences[percentile25Index];

      developer.log('Optimal threshold calculated: ${(optimalThreshold * 100).toStringAsFixed(1)}%');

      return optimalThreshold.clamp(0.5, 0.9); // Limitar entre 50% y 90%
    } catch (e) {
      developer.log('Error calculating optimal threshold: $e', level: 1000);
      return defaultThreshold;
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

  /// Resultado exitoso de identificación
  factory IdentificationResult.identified({
    required Person person,
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

  /// Resultado de no identificación
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
      confidence: bestCandidate?.similarity,
    );
  }

  /// Resultado de error
  factory IdentificationResult.error(String message) {
    return IdentificationResult._(
      isIdentified: false,
      errorMessage: message,
    );
  }

  bool get isError => errorMessage != null;
  bool get hasNoMatch => noMatchReason != null;

  String get statusMessage {
    if (isError) return 'Error: $errorMessage';
    if (isIdentified) return 'Identificado: ${person!.name} (${(confidence! * 100).toStringAsFixed(1)}%)';
    if (hasNoMatch) return 'No identificado: $noMatchReason';
    return 'Estado desconocido';
  }
}

/// Similitud entre una persona y una consulta
class PersonSimilarity {
  final Person person;
  final double similarity;
  final double confidence;

  PersonSimilarity({
    required this.person,
    required this.similarity,
    required this.confidence,
  });

  double get similarityPercent => similarity * 100;
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
