import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../services/identification_service.dart';
import '../services/enhanced_identification_service.dart';
import '../services/camera_service.dart';
import '../services/photo_quality_analyzer.dart';
import '../services/face_detection_service.dart';
import '../services/liveness_detector.dart';
import '../services/database_backup_service.dart';
import '../services/pdf_report_generator.dart';
import '../services/realtime_scanner_service.dart';

/// Provider singleton para DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Provider singleton para FaceEmbeddingService
final faceEmbeddingServiceProvider = Provider<FaceEmbeddingService>((ref) {
  return FaceEmbeddingService();
});

/// Provider singleton para IdentificationService (identificación 1:N)
final identificationServiceProvider = Provider<IdentificationService>((ref) {
  return IdentificationService();
});

/// Provider singleton para EnhancedIdentificationService (NUEVO - con ML Kit)
final enhancedIdentificationServiceProvider = Provider<EnhancedIdentificationService>((ref) {
  return EnhancedIdentificationService();
});

/// Provider singleton para CameraService
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

/// Provider singleton para PhotoQualityAnalyzer
final photoQualityAnalyzerProvider = Provider<PhotoQualityAnalyzer>((ref) {
  return PhotoQualityAnalyzer();
});

/// Provider singleton para FaceDetectionService (ML Kit)
final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

/// Provider singleton para LivenessDetector
final livenessDetectorProvider = Provider<LivenessDetector>((ref) {
  return LivenessDetector();
});

/// Provider para DatabaseBackupService
final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return DatabaseBackupService(databaseService);
});

/// Provider para PDFReportGenerator
final pdfReportGeneratorProvider = Provider<PDFReportGenerator>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return PDFReportGenerator(databaseService);
});

/// Provider para RealtimeScannerService
final realtimeScannerServiceProvider = Provider<RealtimeScannerService>((ref) {
  final faceDetection = ref.watch(faceDetectionServiceProvider);
  final qualityAnalyzer = ref.watch(photoQualityAnalyzerProvider);
  final identificationService = ref.watch(identificationServiceProvider);
  
  return RealtimeScannerService(
    faceDetection: faceDetection,
    qualityAnalyzer: qualityAnalyzer,
    identificationService: identificationService,
  );
});

/// FutureProvider para inicialización de base de datos
final databaseInitializationProvider = FutureProvider<void>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  await Future.delayed(const Duration(milliseconds: 100));
});

/// FutureProvider para inicialización del modelo TFLite
final embeddingInitializationProvider = FutureProvider<void>((ref) async {
  final embeddingService = ref.watch(faceEmbeddingServiceProvider);
  await embeddingService.initialize();
});
