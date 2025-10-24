import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Servicio para gestionar la cámara y captura de imágenes
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  /// Obtiene el controlador de la cámara
  CameraController? get controller => _controller;

  /// Verifica si la cámara está inicializada
  bool get isInitialized => _isInitialized;

  /// Obtiene las cámaras disponibles
  List<CameraDescription> get cameras => _cameras;

  /// Inicializa el servicio de cámara
  Future<bool> initialize() async {
    try {
      // Solicitar permisos
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        throw Exception('Permiso de cámara denegado');
      }

      // Obtener cámaras disponibles
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No hay cámaras disponibles');
      }

      // Buscar cámara frontal (preferida para reconocimiento facial)
      CameraDescription selectedCamera = _cameras.first;
      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      // Inicializar controlador
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false, // No necesitamos audio
      );

      await _controller!.initialize();
      _isInitialized = true;

      return true;
    } catch (e) {
      print('Error al inicializar cámara: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Cambia entre cámara frontal y trasera
  Future<bool> switchCamera() async {
    if (!_isInitialized || _cameras.length < 2) return false;

    try {
      // Obtener cámara actual
      final currentCamera = _controller!.description;

      // Buscar la otra cámara
      CameraDescription newCamera = _cameras.first;
      for (final camera in _cameras) {
        if (camera.lensDirection != currentCamera.lensDirection) {
          newCamera = camera;
          break;
        }
      }

      // Cambiar cámara
      await _controller!.dispose();
      _controller = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      return true;
    } catch (e) {
      print('Error al cambiar cámara: $e');
      return false;
    }
  }

  /// Captura una foto y la guarda en almacenamiento local
  Future<String?> takePicture({String? fileName}) async {
    if (!_isInitialized || _controller == null) return null;

    try {
      // Generar nombre único si no se proporciona
      fileName ??= 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Obtener directorio de aplicación
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String facesPath = join(appDir.path, 'faces');

      // Crear directorio si no existe
      final Directory facesDir = Directory(facesPath);
      if (!await facesDir.exists()) {
        await facesDir.create(recursive: true);
      }

      // Ruta completa del archivo
      final String filePath = join(facesPath, fileName);

      // Capturar foto
      final XFile photo = await _controller!.takePicture();

      // Copiar archivo a ubicación permanente
      await File(photo.path).copy(filePath);

      // Eliminar archivo temporal
      await File(photo.path).delete();

      return filePath;
    } catch (e) {
      print('Error al capturar foto: $e');
      return null;
    }
  }

  /// Obtiene información de la cámara actual
  String getCurrentCameraInfo() {
    if (!_isInitialized || _controller == null) return 'Cámara no inicializada';

    final camera = _controller!.description;
    final direction = camera.lensDirection == CameraLensDirection.front
        ? 'Frontal'
        : 'Trasera';

    return 'Cámara $direction';
  }

  /// Verifica si hay múltiples cámaras disponibles
  bool hasMultipleCameras() => _cameras.length > 1;

  /// Libera los recursos de la cámara
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
  }

  /// Obtiene el directorio donde se guardan las fotos
  Future<String> getFacesDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    return join(appDir.path, 'faces');
  }

  /// Lista todas las fotos guardadas
  Future<List<File>> getSavedPhotos() async {
    try {
      final String facesPath = await getFacesDirectory();
      final Directory facesDir = Directory(facesPath);

      if (!await facesDir.exists()) return [];

      final List<FileSystemEntity> files = await facesDir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.jpg'))
          .toList();
    } catch (e) {
      print('Error al obtener fotos: $e');
      return [];
    }
  }

  /// Elimina una foto específica
  Future<bool> deletePhoto(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error al eliminar foto: $e');
      return false;
    }
  }
}
