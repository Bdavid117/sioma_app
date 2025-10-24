import 'dart:io';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:image/image.dart' as img;
import '../utils/validation_utils.dart';
// import 'package:tflite_flutter/tflite_flutter.dart'; // Temporalmente comentado

/// Servicio para generar embeddings faciales usando TensorFlow Lite
class FaceEmbeddingService {
  static final FaceEmbeddingService _instance = FaceEmbeddingService._internal();
  factory FaceEmbeddingService() => _instance;
  FaceEmbeddingService._internal();

  // Interpreter? _interpreter; // Temporalmente comentado
  bool _isInitialized = false;

  // Dimensiones del modelo (configurables según el modelo real)
  static const int inputSize = 112; // Tamaño de entrada típico para modelos faciales
  static const int embeddingSize = 128; // Tamaño del vector de embeddings

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio de embeddings
  Future<bool> initialize() async {
    try {
      // Por ahora usaremos una implementación simulada
      // En producción, aquí cargarías el modelo TFLite real:
      // _interpreter = await Interpreter.fromAsset('assets/models/face_recognition.tflite');

      _isInitialized = true;
      print('✅ Servicio de embeddings inicializado (modo simulado)');
      return true;
    } catch (e) {
      print('❌ Error al inicializar embeddings: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Genera embedding facial desde una imagen con validaciones de seguridad
  Future<List<double>?> generateEmbedding(String imagePath) async {
    if (!_isInitialized) {
      developer.log('FaceEmbeddingService not initialized');
      return null;
    }

    try {
      // Validar ruta de archivo de entrada
      final pathValidation = ValidationUtils.validateFilePath(imagePath);
      if (!pathValidation.isValid) {
        developer.log('Invalid image path: $imagePath');
        return null;
      }

      // Verificar que el archivo existe y es accesible
      final imageFile = File(pathValidation.value!);
      if (!await imageFile.exists()) {
        developer.log('Image file does not exist: $imagePath');
        return null;
      }

      // Verificar tamaño del archivo por seguridad
      final fileSize = await imageFile.length();
      if (fileSize > 20 * 1024 * 1024) { // Límite de 20MB
        developer.log('Image file too large: ${fileSize} bytes');
        return null;
      }

      if (fileSize < 1024) { // Mínimo 1KB
        developer.log('Image file too small: ${fileSize} bytes');
        return null;
      }

      // Cargar y validar imagen de forma segura
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        developer.log('Failed to decode image: $imagePath');
        return null;
      }

      // Validar dimensiones de imagen
      if (image.width < 32 || image.height < 32) {
        developer.log('Image too small: ${image.width}x${image.height}');
        return null;
      }

      if (image.width > 4096 || image.height > 4096) {
        developer.log('Image too large: ${image.width}x${image.height}');
        return null;
      }

      // Preprocesar la imagen de forma segura
      final processedImage = _preprocessImage(image);

      // Generar embedding con validación
      final embedding = await _runInference(processedImage);

      if (embedding != null && embedding.length == embeddingSize) {
        developer.log('Embedding generated successfully: ${embedding.length} dimensions');
        return embedding;
      }

      developer.log('Failed to generate valid embedding');
      return null;
    } catch (e) {
      developer.log('Error generating embedding: $e', level: 1000);
      return null;
    }
  }

  /// Preprocesa la imagen para el modelo
  img.Image _preprocessImage(img.Image originalImage) {
    // Redimensionar a tamaño requerido por el modelo
    img.Image resized = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Convertir a escala de grises si es necesario (opcional)
    // resized = img.grayscale(resized);

    return resized;
  }

  /// Ejecuta la inferencia del modelo (versión simulada)
  Future<List<double>?> _runInference(img.Image processedImage) async {
    try {
      // IMPLEMENTACIÓN SIMULADA - En producción usarías el modelo TFLite real

      // Convertir imagen a tensor de entrada
      final inputTensor = _imageToTensor(processedImage);

      // Simular embedding basado en características de la imagen
      final embedding = _generateEnhancedEmbedding(processedImage);

      return embedding;

      /* IMPLEMENTACIÓN REAL (comentada para referencia futura):

      // Preparar tensores de entrada y salida
      final input = [inputTensor];
      final output = [List.filled(embeddingSize, 0.0)];

      // Ejecutar inferencia
      _interpreter!.run(input, output);

      // Normalizar embedding
      final rawEmbedding = output[0].cast<double>();
      return _normalizeEmbedding(rawEmbedding);

      */
    } catch (e) {
      print('❌ Error en inferencia: $e');
      return null;
    }
  }

  /// Convierte imagen a tensor (formato requerido por TFLite)
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    final tensor = List.generate(
      1, // batch size
      (i) => List.generate(
        inputSize, // height
        (j) => List.generate(
          inputSize, // width
          (k) => List.generate(
            3, // channels (RGB)
            (l) => 0.0,
          ),
        ),
      ),
    );

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);

        // Extraer componentes RGB del pixel (formato ARGB de 32 bits)
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;

        // Normalizar valores de píxeles a rango [-1, 1]
        tensor[0][y][x][0] = (r / 255.0) * 2.0 - 1.0; // Red
        tensor[0][y][x][1] = (g / 255.0) * 2.0 - 1.0; // Green
        tensor[0][y][x][2] = (b / 255.0) * 2.0 - 1.0; // Blue
      }
    }

    return tensor;
  }

  /// Genera embedding mejorado basado en características faciales avanzadas
  List<double> _generateEnhancedEmbedding(img.Image image) {
    // Análisis de características faciales avanzadas
    final features = _extractAdvancedFacialFeatures(image);
    
    // Generar embedding determinístico basado en características reales
    final embedding = List<double>.generate(embeddingSize, (i) {
      // Combinar múltiples características para cada dimensión del embedding
      final feature1 = features['brightness']! * sin(i * 0.1);
      final feature2 = features['contrast']! * cos(i * 0.15);
      final feature3 = features['colorVariance']! * sin(i * 0.2);
      final feature4 = features['edgeDensity']! * cos(i * 0.25);
      final feature5 = features['symmetry']! * sin(i * 0.3);
      final feature6 = features['texture']! * cos(i * 0.35);
      
      // Combinar todas las características con pesos diferentes
      return (feature1 * 0.3 + feature2 * 0.2 + feature3 * 0.15 + 
              feature4 * 0.15 + feature5 * 0.1 + feature6 * 0.1);
    });

    // Normalizar el embedding para magnitud unitaria
    return _normalizeEmbedding(embedding);
  }

  /// Extrae características faciales avanzadas de la imagen
  Map<String, double> _extractAdvancedFacialFeatures(img.Image image) {
    double totalBrightness = 0.0;
    double redSum = 0.0, greenSum = 0.0, blueSum = 0.0;
    double edgeCount = 0.0;
    List<double> brightnessValues = [];
    
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    double symmetryScore = 0.0;
    int symmetryComparisons = 0;

    // Primera pasada: estadísticas básicas
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;
        
        final brightness = (r + g + b) / 3.0;
        totalBrightness += brightness;
        brightnessValues.add(brightness);
        redSum += r;
        greenSum += g;
        blueSum += b;

        // Detectar bordes usando gradiente simple
        if (x > 0 && y > 0 && x < image.width - 1 && y < image.height - 1) {
          final currentBrightness = brightness;
          final rightPixel = image.getPixel(x + 1, y);
          final bottomPixel = image.getPixel(x, y + 1);
          
          final rightBrightness = ((rightPixel >> 16) & 0xFF) + 
                                 ((rightPixel >> 8) & 0xFF) + 
                                 (rightPixel & 0xFF);
          final bottomBrightness = ((bottomPixel >> 16) & 0xFF) + 
                                  ((bottomPixel >> 8) & 0xFF) + 
                                  (bottomPixel & 0xFF);
          
          final gradientX = (rightBrightness / 3.0 - currentBrightness).abs();
          final gradientY = (bottomBrightness / 3.0 - currentBrightness).abs();
          
          if (gradientX > 30 || gradientY > 30) edgeCount++;
        }

        // Calcular simetría (comparar píxeles espejados)
        if (x < centerX && x < image.width - x - 1) {
          final mirrorPixel = image.getPixel(image.width - x - 1, y);
          final mirrorBrightness = (((mirrorPixel >> 16) & 0xFF) + 
                                  ((mirrorPixel >> 8) & 0xFF) + 
                                  (mirrorPixel & 0xFF)) / 3.0;
          
          symmetryScore += (brightness - mirrorBrightness).abs();
          symmetryComparisons++;
        }
      }
    }

    final totalPixels = image.width * image.height;
    final avgBrightness = totalBrightness / totalPixels;
    
    // Calcular contraste (varianza de brillo)
    double varianceSum = 0.0;
    for (final brightness in brightnessValues) {
      varianceSum += pow(brightness - avgBrightness, 2);
    }
    final contrast = sqrt(varianceSum / totalPixels);

    // Calcular varianza de color
    final avgRed = redSum / totalPixels;
    final avgGreen = greenSum / totalPixels;
    final avgBlue = blueSum / totalPixels;
    final colorVariance = sqrt(pow(avgRed - avgGreen, 2) + 
                              pow(avgGreen - avgBlue, 2) + 
                              pow(avgBlue - avgRed, 2));

    // Normalizar valores para rango consistente
    return {
      'brightness': (avgBrightness / 255.0).clamp(0.0, 1.0),
      'contrast': (contrast / 100.0).clamp(0.0, 1.0),
      'colorVariance': (colorVariance / 200.0).clamp(0.0, 1.0),
      'edgeDensity': (edgeCount / (totalPixels * 0.01)).clamp(0.0, 1.0),
      'symmetry': symmetryComparisons > 0 ? 
                  (1.0 - (symmetryScore / symmetryComparisons) / 100.0).clamp(0.0, 1.0) : 0.5,
      'texture': (contrast / avgBrightness).clamp(0.0, 1.0),
    };
  }

  /// Normaliza el embedding (magnitud = 1)
  List<double> _normalizeEmbedding(List<double> embedding) {
    final magnitude = sqrt(embedding.fold<double>(0.0, (sum, val) => sum + val * val));

    if (magnitude == 0.0) return embedding;

    return embedding.map((val) => val / magnitude).toList();
  }

  /// Calcula la similitud coseno entre dos embeddings
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Los embeddings deben tener la misma longitud');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Encuentra la mejor coincidencia entre un embedding y una lista de embeddings
  Map<String, dynamic> findBestMatch(
    List<double> queryEmbedding,
    Map<int, List<double>> storedEmbeddings,
    {double threshold = 0.7}
  ) {
    double bestSimilarity = -1.0;
    int? bestPersonId;

    for (final entry in storedEmbeddings.entries) {
      final similarity = calculateSimilarity(queryEmbedding, entry.value);

      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestPersonId = entry.key;
      }
    }

    final isMatch = bestSimilarity >= threshold;

    return {
      'personId': isMatch ? bestPersonId : null,
      'similarity': bestSimilarity,
      'confidence': bestSimilarity,
      'isMatch': isMatch,
    };
  }

  /// Convierte embedding a string JSON para almacenar en BD
  String embeddingToJson(List<double> embedding) {
    return embedding.toString();
  }

  /// Convierte string JSON a embedding
  List<double> embeddingFromJson(String jsonString) {
    // Remover corchetes y espacios
    final cleanString = jsonString.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');

    // Dividir por comas y convertir a double
    return cleanString.split(',').map((s) => double.parse(s)).toList();
  }

  /// Libera recursos
  Future<void> dispose() async {
    // _interpreter?.close(); // Temporalmente comentado
    // _interpreter = null; // Temporalmente comentado
    _isInitialized = false;
  }

  /// Información del modelo
  Map<String, dynamic> getModelInfo() {
    return {
      'inputSize': inputSize,
      'embeddingSize': embeddingSize,
      'isInitialized': _isInitialized,
      'mode': 'simulated', // cambiar a 'tflite' cuando uses modelo real
    };
  }
}

/// Extensión para generar números aleatorios con distribución gaussiana
extension on Random {
  double nextGaussian() {
    double u1 = nextDouble();
    double u2 = nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
