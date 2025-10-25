import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../services/identification_service.dart';
import '../services/camera_service.dart';
import '../services/photo_quality_analyzer.dart';

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

/// Provider singleton para CameraService
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

/// Provider singleton para PhotoQualityAnalyzer
final photoQualityAnalyzerProvider = Provider<PhotoQualityAnalyzer>((ref) {
  return PhotoQualityAnalyzer();
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
