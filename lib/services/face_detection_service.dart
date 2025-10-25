import 'dart:io';
import 'package:flutter/material.dart'; // Para Rect
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/app_logger.dart';

/// Servicio de detección facial usando Google ML Kit
/// Detecta rostros, valida posicionamiento y calidad del rostro
class FaceDetectionService {
  late final FaceDetector _faceDetector;
  
  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15, // 15% del tamaño de la imagen
      ),
    );
  }

  /// Detecta rostros en una imagen
  /// Retorna resultado con validaciones de calidad
  Future<FaceDetectionResult> detectFaces(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      BiometricLogger.info('🔍 ML Kit detectó ${faces.length} rostro(s)');

      if (faces.isEmpty) {
        return FaceDetectionResult(
          success: false,
          faceCount: 0,
          errorMessage: 'No se detectó ningún rostro',
          recommendations: ['Asegúrate de que tu rostro esté visible', 'Mejora la iluminación'],
        );
      }

      if (faces.length > 1) {
        return FaceDetectionResult(
          success: false,
          faceCount: faces.length,
          errorMessage: 'Se detectaron múltiples rostros',
          recommendations: ['Asegúrate de que solo haya una persona en la foto'],
        );
      }

      // Analizar el único rostro detectado
      final face = faces.first;
      final analysis = _analyzeFaceQuality(face);

      BiometricLogger.info(
        '✅ Rostro analizado: '
        'Score=${(analysis.qualityScore * 100).toStringAsFixed(0)}%, '
        'Centrado=${analysis.isCentered}, '
        'Ángulo=${analysis.headAngle.toStringAsFixed(1)}°'
      );

      return FaceDetectionResult(
        success: analysis.isAcceptable,
        faceCount: 1,
        face: face,
        analysis: analysis,
        errorMessage: analysis.isAcceptable ? null : 'Calidad de rostro insuficiente',
        recommendations: analysis.recommendations,
      );

    } catch (e, stackTrace) {
      BiometricLogger.error('Error en detección facial ML Kit', e, stackTrace);
      return FaceDetectionResult(
        success: false,
        faceCount: 0,
        errorMessage: 'Error al procesar imagen: $e',
        recommendations: ['Intenta capturar nuevamente'],
      );
    }
  }

  /// Analiza la calidad del rostro detectado
  FaceQualityAnalysis _analyzeFaceQuality(Face face) {
    final recommendations = <String>[];
    double qualityScore = 1.0;

    // 1. Validar que el rostro esté centrado
    final boundingBox = face.boundingBox;
    final centerX = boundingBox.left + (boundingBox.width / 2);
    final centerY = boundingBox.top + (boundingBox.height / 2);
    
    // Asumiendo imagen de ~1080x1920 (se puede ajustar dinámicamente)
    final isCentered = (centerX > 400 && centerX < 680) && 
                       (centerY > 700 && centerY < 1220);
    
    if (!isCentered) {
      qualityScore -= 0.2;
      recommendations.add('📍 Centra tu rostro en la guía oval');
    }

    // 2. Validar ángulo de rotación de la cabeza
    final headEulerAngleY = face.headEulerAngleY ?? 0; // Rotación izq/der
    final headEulerAngleZ = face.headEulerAngleZ ?? 0; // Inclinación
    final headAngle = (headEulerAngleY.abs() + headEulerAngleZ.abs()) / 2;

    if (headAngle > 15) {
      qualityScore -= 0.3;
      recommendations.add('👤 Mira directamente a la cámara');
    } else if (headAngle > 8) {
      qualityScore -= 0.15;
      recommendations.add('⚠️ Ajusta ligeramente tu posición');
    }

    // 3. Validar que los ojos estén abiertos (si está disponible)
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;
    
    if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) {
      qualityScore -= 0.25;
      recommendations.add('👁️ Mantén los ojos abiertos');
    }

    // 4. Validar probabilidad de sonrisa (opcional, no penalizar)
    final smiling = face.smilingProbability ?? 0;
    if (smiling < 0.3) {
      // No afectar score, solo sugerir
      recommendations.add('😊 Una leve sonrisa mejora la detección');
    }

    // 5. Validar tamaño del rostro (muy pequeño o muy grande)
    final faceSize = boundingBox.width * boundingBox.height;
    if (faceSize < 50000) { // Muy pequeño
      qualityScore -= 0.2;
      recommendations.add('🔍 Acércate un poco más');
    } else if (faceSize > 400000) { // Muy grande
      qualityScore -= 0.15;
      recommendations.add('↔️ Aléjate un poco');
    }

    // Clamp score entre 0 y 1
    qualityScore = qualityScore.clamp(0.0, 1.0);

    if (recommendations.isEmpty && qualityScore >= 0.8) {
      recommendations.add('✅ Posicionamiento perfecto');
    }

    return FaceQualityAnalysis(
      qualityScore: qualityScore,
      isCentered: isCentered,
      headAngle: headAngle,
      leftEyeOpen: leftEyeOpen,
      rightEyeOpen: rightEyeOpen,
      smiling: smiling,
      boundingBox: boundingBox,
      isAcceptable: qualityScore >= 0.6, // Threshold 60%
      recommendations: recommendations,
    );
  }

  /// Libera recursos
  void dispose() {
    _faceDetector.close();
    BiometricLogger.debug('FaceDetectionService disposed');
  }
}

/// Resultado de la detección facial
class FaceDetectionResult {
  final bool success;
  final int faceCount;
  final Face? face;
  final FaceQualityAnalysis? analysis;
  final String? errorMessage;
  final List<String> recommendations;

  FaceDetectionResult({
    required this.success,
    required this.faceCount,
    this.face,
    this.analysis,
    this.errorMessage,
    this.recommendations = const [],
  });

  bool get hasOneFace => faceCount == 1;
  bool get isHighQuality => (analysis?.qualityScore ?? 0.0) >= 0.8;
  
  String get statusMessage {
    if (!success) return errorMessage ?? 'Error desconocido';
    if (analysis == null) return 'Procesando...';
    
    final score = (analysis!.qualityScore * 100).toInt();
    if (score >= 80) return '✅ Excelente calidad ($score%)';
    if (score >= 60) return '⚠️ Calidad aceptable ($score%)';
    return '❌ Calidad baja ($score%)';
  }
}

/// Análisis de calidad del rostro
class FaceQualityAnalysis {
  final double qualityScore; // 0.0 - 1.0
  final bool isCentered;
  final double headAngle; // Grados de rotación
  final double leftEyeOpen; // Probabilidad 0-1
  final double rightEyeOpen; // Probabilidad 0-1
  final double smiling; // Probabilidad 0-1
  final Rect boundingBox;
  final bool isAcceptable;
  final List<String> recommendations;

  FaceQualityAnalysis({
    required this.qualityScore,
    required this.isCentered,
    required this.headAngle,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.smiling,
    required this.boundingBox,
    required this.isAcceptable,
    required this.recommendations,
  });

  String get qualityLevel {
    if (qualityScore >= 0.8) return 'Excelente';
    if (qualityScore >= 0.6) return 'Buena';
    if (qualityScore >= 0.4) return 'Regular';
    return 'Baja';
  }

  @override
  String toString() {
    return 'FaceQuality(score: ${(qualityScore * 100).toInt()}%, '
        'level: $qualityLevel, centered: $isCentered, angle: ${headAngle.toStringAsFixed(1)}°)';
  }
}
