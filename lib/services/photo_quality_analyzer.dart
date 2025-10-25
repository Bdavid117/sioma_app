import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../utils/app_logger.dart';

/// Servicio que analiza la calidad de fotos en tiempo real
/// para determinar el momento óptimo de captura automática
class PhotoQualityAnalyzer {
  static const double _minBrightnessScore = 0.25; // Menos estricto
  static const double _maxBrightnessScore = 0.85;
  static const double _optimalQualityThreshold = 0.65; // Reducido de 0.75 a 0.65

  /// Analiza la calidad de una imagen capturada
  /// Retorna un score de 0.0 a 1.0 indicando qué tan buena es la foto
  Future<PhotoQualityResult> analyzePhoto(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        CameraLogger.error('Archivo de imagen no existe', imagePath);
        return PhotoQualityResult.poor('Archivo no encontrado');
      }

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        CameraLogger.error('No se pudo decodificar la imagen', imagePath);
        return PhotoQualityResult.poor('Error al decodificar imagen');
      }

      // Análisis de calidad
      final brightness = _analyzeBrightness(image);
      final sharpness = _analyzeSharpness(image);
      final contrast = _analyzeContrast(image);

      // Score combinado
      final qualityScore = _calculateQualityScore(brightness, sharpness, contrast);

      final result = PhotoQualityResult(
        qualityScore: qualityScore,
        brightnessScore: brightness,
        sharpnessScore: sharpness,
        contrastScore: contrast,
        isOptimal: qualityScore >= _optimalQualityThreshold,
        recommendations: _generateRecommendations(brightness, sharpness, contrast),
      );

      CameraLogger.info('✅ Análisis de calidad: ${(qualityScore * 100).toStringAsFixed(0)}% - ${result.qualityLevel}');

      return result;
    } catch (e) {
      CameraLogger.error('Error analizando calidad de foto', e);
      return PhotoQualityResult.poor('Error en análisis: $e');
    }
  }

  /// Analiza el brillo de la imagen
  double _analyzeBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;

    // Muestreo: analizar cada 10 píxeles para rendimiento
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        // En image 4.x, pixel es Pixel object
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        // Luminosidad percibida
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        totalBrightness += brightness.toInt();
        pixelCount++;
      }
    }

    final avgBrightness = totalBrightness / pixelCount / 255.0;

    // Score basado en rango óptimo
    if (avgBrightness < _minBrightnessScore) {
      return avgBrightness / _minBrightnessScore; // Muy oscuro
    } else if (avgBrightness > _maxBrightnessScore) {
      return 1.0 - ((avgBrightness - _maxBrightnessScore) / (1.0 - _maxBrightnessScore)); // Muy claro
    } else {
      return 1.0; // Óptimo
    }
  }

  /// Analiza la nitidez (sharpness) usando detección de bordes
  double _analyzeSharpness(img.Image image) {
    try {
      // Convertir a escala de grises
      final grayscale = img.grayscale(image);

      int edgeStrength = 0;
      int edgeCount = 0;
      int totalPixels = 0;

      // Detector de bordes simple (Sobel aproximado) - muestreo más amplio
      for (int y = 1; y < grayscale.height - 1; y += 8) { // Reducido de 10 a 8
        for (int x = 1; x < grayscale.width - 1; x += 8) {
          final center = grayscale.getPixel(x, y).r.toInt();
          final right = grayscale.getPixel(x + 1, y).r.toInt();
          final down = grayscale.getPixel(x, y + 1).r.toInt();

          final gradientX = (right - center).abs();
          final gradientY = (down - center).abs();
          final gradient = gradientX + gradientY;

          totalPixels++;
          if (gradient > 15) { // Reducido umbral de 20 a 15 (menos estricto)
            edgeStrength += gradient;
            edgeCount++;
          }
        }
      }

      if (edgeCount == 0 || totalPixels == 0) return 0.3; // Valor base en vez de 0.0

      // Calcular score normalizado
      final edgeRatio = edgeCount / totalPixels;
      final avgEdgeStrength = edgeStrength / edgeCount / 255.0;
      
      // Combinar ratio de bordes con fuerza promedio
      final sharpnessScore = (edgeRatio * 0.6 + avgEdgeStrength * 0.4) * 1.5; // Multiplicador para boost
      
      return sharpnessScore.clamp(0.0, 1.0);
    } catch (e) {
      CameraLogger.error('Error en análisis de nitidez', e);
      return 0.5; // Valor neutro en caso de error
    }
  }

  /// Analiza el contraste de la imagen
  double _analyzeContrast(img.Image image) {
    List<int> brightness = [];

    // Muestreo de píxeles
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final luma = (0.299 * r + 0.587 * g + 0.114 * b).toInt();
        brightness.add(luma);
      }
    }

    if (brightness.isEmpty) return 0.0;

    // Calcular desviación estándar
    final mean = brightness.reduce((a, b) => a + b) / brightness.length;
    final variance = brightness
        .map((b) => (b - mean) * (b - mean))
        .reduce((a, b) => a + b) / brightness.length;
    final stdDev = variance < 0 ? 0.0 : math.sqrt(variance);

    // Normalizar contraste (desviación estándar típica: 0-70)
    final contrastScore = (stdDev / 70.0).clamp(0.0, 1.0);
    return contrastScore;
  }

  /// Calcula score de calidad combinado
  double _calculateQualityScore(double brightness, double sharpness, double contrast) {
    // Pesos ajustados: brillo más importante, nitidez menos estricta
    const brightnessWeight = 0.45; // Aumentado de 0.30
    const sharpnessWeight = 0.35; // Reducido de 0.50
    const contrastWeight = 0.20; // Igual

    return (brightness * brightnessWeight) +
           (sharpness * sharpnessWeight) +
           (contrast * contrastWeight);
  }

  /// Genera recomendaciones basadas en análisis
  List<String> _generateRecommendations(double brightness, double sharpness, double contrast) {
    List<String> recommendations = [];

    if (brightness < 0.5) {
      recommendations.add('💡 Aumenta la iluminación');
    } else if (brightness < 0.7) {
      recommendations.add('🌟 Iluminación aceptable');
    }

    if (sharpness < 0.5) {
      recommendations.add('📸 Mantén la cámara estable');
    } else if (sharpness >= 0.7) {
      recommendations.add('✨ Imagen nítida');
    }

    if (contrast < 0.4) {
      recommendations.add('🎨 Mejora el contraste (fondo uniforme)');
    }

    return recommendations;
  }
}

/// Resultado del análisis de calidad de foto
class PhotoQualityResult {
  final double qualityScore;
  final double brightnessScore;
  final double sharpnessScore;
  final double contrastScore;
  final bool isOptimal;
  final List<String> recommendations;
  final String? errorMessage;

  PhotoQualityResult({
    required this.qualityScore,
    required this.brightnessScore,
    required this.sharpnessScore,
    required this.contrastScore,
    required this.isOptimal,
    required this.recommendations,
    this.errorMessage,
  });

  factory PhotoQualityResult.poor(String reason) {
    return PhotoQualityResult(
      qualityScore: 0.0,
      brightnessScore: 0.0,
      sharpnessScore: 0.0,
      contrastScore: 0.0,
      isOptimal: false,
      recommendations: [],
      errorMessage: reason,
    );
  }

  String get qualityLevel {
    if (qualityScore >= 0.8) return 'Excelente';
    if (qualityScore >= 0.6) return 'Buena';
    if (qualityScore >= 0.4) return 'Regular';
    return 'Baja';
  }

  @override
  String toString() {
    return 'PhotoQuality(score: ${qualityScore.toStringAsFixed(2)}, '
        'level: $qualityLevel, optimal: $isOptimal)';
  }
}
