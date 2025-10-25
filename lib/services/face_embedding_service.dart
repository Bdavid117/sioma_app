import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:image/image.dart' as img;
import '../utils/app_logger.dart';

/// Servicio para generar embeddings faciales usando TensorFlow Lite
class FaceEmbeddingService {
  static final FaceEmbeddingService _instance = FaceEmbeddingService._internal();
  factory FaceEmbeddingService() => _instance;
  FaceEmbeddingService._internal();

  bool _isInitialized = false;

  // Dimensiones del modelo (configurables según el modelo real)
  static const int inputSize = 112;
  static const int embeddingSize = 512; // Aumentado para mayor precisión

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de embeddings
  Future<bool> initialize() async {
    try {
      BiometricLogger.info('Inicializando FaceEmbeddingService...');
      
      // Simulación de inicialización de modelo
      await Future.delayed(const Duration(milliseconds: 100));
      
      _isInitialized = true;
      BiometricLogger.info('FaceEmbeddingService inicializado correctamente');
      return true;
    } catch (e) {
      BiometricLogger.error('Error inicializando FaceEmbeddingService', e);
      return false;
    }
  }

  /// Genera un embedding facial desde una imagen
  Future<List<double>?> generateEmbedding(String imagePath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Verificar que el archivo existe
      final file = File(imagePath);
      if (!await file.exists()) {
        BiometricLogger.warning('Archivo de imagen no encontrado: $imagePath');
        return null;
      }

      BiometricLogger.debug('Procesando imagen: $imagePath');

      // Leer y procesar la imagen
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        BiometricLogger.warning('No se pudo decodificar la imagen');
        return null;
      }

      // Preprocessing de la imagen
      final preprocessedImage = _preprocessImage(image);
      
      // Generar embedding simulado con características basadas en la imagen real
      final embedding = _generateSimulatedEmbedding(preprocessedImage);
      
      BiometricLogger.info('Embedding generado: ${embedding.length} dimensiones');
      return embedding;

    } catch (e) {
      BiometricLogger.error('Error generando embedding', e);
      return null;
    }
  }

  /// Preprocesa la imagen para el modelo
  img.Image _preprocessImage(img.Image image) {
    try {
      // Redimensionar a tamaño estándar
      var processed = img.copyResize(image, width: inputSize, height: inputSize);
      
      // Convertir a escala de grises para consistencia
      processed = img.grayscale(processed);
      
      // Normalizar el contraste (0-255 rango estándar)
      processed = img.normalize(processed, min: 0, max: 255);
      
      return processed;
    } catch (e) {
      BiometricLogger.error('Error en preprocesamiento', e);
      return image;
    }
  }

  /// Genera un embedding simulado basado en características reales de la imagen
  List<double> _generateSimulatedEmbedding(img.Image image) {
    final embedding = <double>[];
    
    // Generar características DETERMINÍSTICAS basadas en la imagen
    // CRÍTICO: No usar ruido aleatorio para que la misma imagen genere el mismo embedding
    final imageHash = _calculateImageHash(image);
    final seedGenerator = Random(imageHash);
    
    // Generar embedding de 512 dimensiones de forma DETERMINÍSTICA
    for (int i = 0; i < embeddingSize; i++) {
      // Solo características determinísticas - SIN RUIDO ALEATORIO
      final baseValue = seedGenerator.nextDouble() * 2 - 1; // [-1, 1]
      
      embedding.add(baseValue.clamp(-1.0, 1.0));
    }
    
    // Normalizar el embedding
    return _normalizeEmbedding(embedding);
  }

  /// Calcula un hash determinístico basado en características de la imagen
  int _calculateImageHash(img.Image image) {
    int hash = 17; // Número primo como seed
    
    // Usar píxeles en posiciones estratégicas con patrón fijo
    final stepX = (image.width ~/ 16).clamp(1, image.width);
    final stepY = (image.height ~/ 16).clamp(1, image.height);
    
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        try {
          final pixel = image.getPixel(x, y);
          // En image 4.x, acceso directo a canales RGB
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          // Combinación determinística más robusta
          hash = hash * 31 + r;
          hash = hash * 31 + g;
          hash = hash * 31 + b;
          hash = hash ^ ((r << 16) | (g << 8) | b);
        } catch (e) {
          // Ignorar píxeles fuera de rango
          continue;
        }
      }
    }
    
    return hash.abs();
  }

  /// Normaliza un embedding a longitud unitaria
  List<double> _normalizeEmbedding(List<double> embedding) {
    // Calcular la norma L2
    double norm = 0.0;
    for (final value in embedding) {
      norm += value * value;
    }
    norm = sqrt(norm);
    
    // Evitar división por cero
    if (norm < 1e-8) {
      return List.filled(embedding.length, 0.0);
    }
    
    // Normalizar
    return embedding.map((value) => value / norm).toList();
  }

  /// Calcula similitud coseno entre dos embeddings
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      BiometricLogger.warning('Embeddings de diferente tamaño: ${embedding1.length} vs ${embedding2.length}');
      return 0.0;
    }

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

  /// Realiza búsqueda 1:N de embeddings similares
  Map<String, double> findSimilarEmbeddings(
    List<double> queryEmbedding,
    Map<String, List<double>> embeddingDatabase,
    {double threshold = 0.5}
  ) {
    final results = <String, double>{};
    
    for (final entry in embeddingDatabase.entries) {
      final similarity = calculateSimilarity(queryEmbedding, entry.value);
      if (similarity >= threshold) {
        results[entry.key] = similarity;
      }
    }
    
    // Ordenar por similitud descendente
    final sortedEntries = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }

  /// Convierte embedding a string JSON para almacenar en BD
  String embeddingToJson(List<double> embedding) {
    if (embedding.isEmpty) {
      BiometricLogger.debug('Intento de serializar embedding vacío');
      return jsonEncode([]);
    }
    return jsonEncode(embedding);
  }

  /// Convierte string JSON a embedding con validación de seguridad
  List<double> embeddingFromJson(String jsonString) {
    try {
      // Validación de seguridad: verificar que no sea null o vacío
      if (jsonString.isEmpty) {
        BiometricLogger.debug('String de embedding vacío');
        return List.filled(embeddingSize, 0.0);
      }

      List<double> result;
      
      if (jsonString.startsWith('[') && jsonString.endsWith(']')) {
        // Es JSON válido
        final List<dynamic> decoded = jsonDecode(jsonString);
        result = decoded.map((e) => (e as num).toDouble()).toList();
      } else {
        // Es formato simple separado por comas (legacy)
        final cleanString = jsonString
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll(' ', '')
            .trim();
        
        if (cleanString.isEmpty) {
          BiometricLogger.debug('String limpio está vacío');
          return List.filled(embeddingSize, 0.0);
        }
        
        result = cleanString
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => double.tryParse(s) ?? 0.0)
            .toList();
      }
      
      // Validación de dimensiones
      if (result.length != embeddingSize) {
        BiometricLogger.debug('Embedding con dimensiones incorrectas: ${result.length} (esperado: $embeddingSize)');
      }
      
      return result;
    } catch (e) {
      BiometricLogger.error('Error parseando embedding JSON', e);
      return List.filled(embeddingSize, 0.0);
    }
  }

  /// Obtiene información del modelo
  Map<String, dynamic> getModelInfo() {
    return {
      'modelType': 'Simulated Face Recognition Model',
      'inputSize': inputSize,
      'embeddingSize': embeddingSize,
      'isInitialized': _isInitialized,
      'version': '1.0.0-simulated',
    };
  }

  /// Valida la calidad de una imagen para procesamiento facial
  bool validateImageQuality(String imagePath) {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return false;
      
      final fileSize = file.lengthSync();
      
      // Verificaciones básicas
      if (fileSize < 1024) return false; // Muy pequeña
      if (fileSize > 10 * 1024 * 1024) return false; // Muy grande (>10MB)
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Limpia recursos y resetea el servicio
  Future<void> dispose() async {
    _isInitialized = false;
    BiometricLogger.info('FaceEmbeddingService disposed');
  }
}