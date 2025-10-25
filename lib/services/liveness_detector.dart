import 'dart:async';
import 'package:flutter/material.dart'; // Para Rect
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/app_logger.dart';

/// Detector de vida (Liveness) para prevenir spoofing con fotos
/// Implementa detección básica de parpadeo y movimiento
class LivenessDetector {
  /// Detecta si hay un rostro "vivo" mediante análisis de parpadeo
  /// Requiere que el usuario parpadee al menos una vez en 3 segundos
  Future<LivenessResult> checkLivenessByBlink({
    required List<String> imagePaths,
  }) async {
    try {
      if (imagePaths.length < 3) {
        return LivenessResult(
          isLive: false,
          confidence: 0.0,
          method: 'blink',
          message: 'Se requieren al menos 3 frames para análisis',
        );
      }

      BiometricLogger.info('🔍 Iniciando detección de vida (Blink Detection)');

      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      List<double> leftEyeStates = [];
      List<double> rightEyeStates = [];

      // Analizar cada frame
      for (final imagePath in imagePaths) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final faces = await faceDetector.processImage(inputImage);

        if (faces.isEmpty) {
          await faceDetector.close();
          return LivenessResult(
            isLive: false,
            confidence: 0.0,
            method: 'blink',
            message: 'No se detectó rostro en todos los frames',
          );
        }

        final face = faces.first;
        leftEyeStates.add(face.leftEyeOpenProbability ?? 0.5);
        rightEyeStates.add(face.rightEyeOpenProbability ?? 0.5);
      }

      await faceDetector.close();

      // Detectar parpadeo: buscar cambio de abierto -> cerrado -> abierto
      final blinkDetected = _detectBlinkPattern(leftEyeStates, rightEyeStates);

      BiometricLogger.info(
        blinkDetected 
          ? '✅ Parpadeo detectado - Persona real'
          : '⚠️ No se detectó parpadeo - Posible foto'
      );

      return LivenessResult(
        isLive: blinkDetected,
        confidence: blinkDetected ? 0.85 : 0.2,
        method: 'blink',
        message: blinkDetected 
          ? 'Detección de vida exitosa'
          : 'No se detectó movimiento de ojos',
        eyeStates: {
          'left': leftEyeStates,
          'right': rightEyeStates,
        },
      );

    } catch (e, stackTrace) {
      BiometricLogger.error('Error en liveness detection', e, stackTrace);
      return LivenessResult(
        isLive: false,
        confidence: 0.0,
        method: 'blink',
        message: 'Error en detección: $e',
      );
    }
  }

  /// Detecta patrón de parpadeo en las probabilidades de ojos
  bool _detectBlinkPattern(List<double> leftEye, List<double> rightEye) {
    if (leftEye.length < 3 || rightEye.length < 3) return false;

    const openThreshold = 0.6; // Ojo considerado abierto
    const closedThreshold = 0.3; // Ojo considerado cerrado

    bool blinkFound = false;

    // Buscar patrón: abierto -> cerrado -> abierto
    for (int i = 0; i < leftEye.length - 2; i++) {
      final wasOpen = leftEye[i] > openThreshold && rightEye[i] > openThreshold;
      final wasClosed = leftEye[i + 1] < closedThreshold || rightEye[i + 1] < closedThreshold;
      final isOpenAgain = leftEye[i + 2] > openThreshold && rightEye[i + 2] > openThreshold;

      if (wasOpen && wasClosed && isOpenAgain) {
        blinkFound = true;
        BiometricLogger.debug('Parpadeo detectado en frames ${i}-${i+2}');
        break;
      }
    }

    return blinkFound;
  }

  /// Detecta vida mediante análisis de diferencias entre frames
  /// Valida que haya movimiento mínimo (no es una foto estática)
  Future<LivenessResult> checkLivenessByMovement({
    required List<String> imagePaths,
  }) async {
    try {
      if (imagePaths.length < 2) {
        return LivenessResult(
          isLive: false,
          confidence: 0.0,
          method: 'movement',
          message: 'Se requieren al menos 2 frames',
        );
      }

      BiometricLogger.info('🔍 Iniciando detección de vida (Movement Analysis)');

      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      List<Rect> boundingBoxes = [];

      // Obtener bounding boxes de cada frame
      for (final imagePath in imagePaths) {
        final inputImage = InputImage.fromFilePath(imagePath);
        final faces = await faceDetector.processImage(inputImage);

        if (faces.isEmpty) {
          await faceDetector.close();
          return LivenessResult(
            isLive: false,
            confidence: 0.0,
            method: 'movement',
            message: 'No se detectó rostro en todos los frames',
          );
        }

        boundingBoxes.add(faces.first.boundingBox);
      }

      await faceDetector.close();

      // Calcular movimiento total
      double totalMovement = 0.0;
      for (int i = 0; i < boundingBoxes.length - 1; i++) {
        final box1 = boundingBoxes[i];
        final box2 = boundingBoxes[i + 1];
        
        final dx = (box1.left - box2.left).abs();
        final dy = (box1.top - box2.top).abs();
        final movement = dx + dy;
        
        totalMovement += movement;
      }

      final avgMovement = totalMovement / (boundingBoxes.length - 1);

      // Si hay movimiento mínimo (>5px promedio) = persona real
      // Si no hay movimiento = posible foto impresa
      const movementThreshold = 5.0;
      final isLive = avgMovement > movementThreshold;

      BiometricLogger.info(
        isLive
          ? '✅ Movimiento detectado (${avgMovement.toStringAsFixed(1)}px) - Persona real'
          : '⚠️ Sin movimiento (${avgMovement.toStringAsFixed(1)}px) - Posible foto'
      );

      return LivenessResult(
        isLive: isLive,
        confidence: isLive ? (avgMovement / 20).clamp(0.6, 0.95) : 0.3,
        method: 'movement',
        message: isLive
          ? 'Movimiento natural detectado'
          : 'No se detectó movimiento suficiente',
        movementData: {
          'average': avgMovement,
          'total': totalMovement,
          'frames': boundingBoxes.length,
        },
      );

    } catch (e, stackTrace) {
      BiometricLogger.error('Error en movement detection', e, stackTrace);
      return LivenessResult(
        isLive: false,
        confidence: 0.0,
        method: 'movement',
        message: 'Error en detección: $e',
      );
    }
  }

  /// Detecta vida usando múltiples métodos combinados
  Future<LivenessResult> checkLivenessCombined({
    required List<String> imagePaths,
  }) async {
    if (imagePaths.length < 3) {
      return LivenessResult(
        isLive: false,
        confidence: 0.0,
        method: 'combined',
        message: 'Se requieren al menos 3 frames para análisis combinado',
      );
    }

    BiometricLogger.info('🔍 Iniciando detección de vida (Método Combinado)');

    // Ejecutar ambos métodos
    final blinkResult = await checkLivenessByBlink(imagePaths: imagePaths);
    final movementResult = await checkLivenessByMovement(imagePaths: imagePaths);

    // Combinar resultados (ambos deben pasar o al menos uno con alta confianza)
    final combinedConfidence = (blinkResult.confidence * 0.6) + 
                               (movementResult.confidence * 0.4);
    
    final isLive = combinedConfidence >= 0.6;

    BiometricLogger.info(
      '📊 Resultado combinado: '
      'Parpadeo=${(blinkResult.confidence * 100).toInt()}%, '
      'Movimiento=${(movementResult.confidence * 100).toInt()}%, '
      'Final=${(combinedConfidence * 100).toInt()}%'
    );

    return LivenessResult(
      isLive: isLive,
      confidence: combinedConfidence,
      method: 'combined',
      message: isLive
        ? 'Persona real detectada (análisis combinado)'
        : 'Posible intento de spoofing',
      combinedResults: {
        'blink': blinkResult,
        'movement': movementResult,
      },
    );
  }
}

/// Resultado de la detección de vida
class LivenessResult {
  final bool isLive;
  final double confidence; // 0.0 - 1.0
  final String method; // 'blink', 'movement', 'combined'
  final String message;
  final Map<String, dynamic>? eyeStates;
  final Map<String, dynamic>? movementData;
  final Map<String, LivenessResult>? combinedResults;

  LivenessResult({
    required this.isLive,
    required this.confidence,
    required this.method,
    required this.message,
    this.eyeStates,
    this.movementData,
    this.combinedResults,
  });

  String get confidenceLevel {
    if (confidence >= 0.9) return 'Muy Alta';
    if (confidence >= 0.7) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    if (confidence >= 0.3) return 'Baja';
    return 'Muy Baja';
  }

  @override
  String toString() {
    return 'LivenessResult(isLive: $isLive, confidence: ${(confidence * 100).toInt()}%, method: $method)';
  }
}
