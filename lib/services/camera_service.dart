import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../utils/validation_utils.dart';
import 'dart:developer' as developer;

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

  /// Captura una foto y la guarda en almacenamiento local con validaciones de seguridad
  Future<String?> takePicture({String? fileName}) async {
    if (!_isInitialized || _controller == null) {
      developer.log('Camera not initialized or controller is null');
      return null;
    }

    try {
      // Validar y sanitizar nombre de archivo
      if (fileName != null) {
        // Prevenir path traversal y caracteres peligrosos
        fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        fileName = fileName.replaceAll('..', '_');
        if (fileName.isEmpty || fileName.length > 100) {
          fileName = null;
        }
      }

      // Generar nombre seguro si no se proporciona o es inválido
      fileName ??= 'face_${ValidationUtils.generateSecureId()}.jpg';

      // Asegurar extensión correcta
      if (!fileName.toLowerCase().endsWith('.jpg')) {
        fileName = '${fileName.split('.').first}.jpg';
      }

      // Obtener directorio de aplicación de forma segura
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String facesPath = join(appDir.path, 'faces');

      // Crear directorio con permisos seguros si no existe
      final Directory facesDir = Directory(facesPath);
      if (!await facesDir.exists()) {
        await facesDir.create(recursive: true);
      }

      // Validar ruta final antes de usar
      final String filePath = join(facesPath, fileName);
      final pathValidation = ValidationUtils.validateFilePath(filePath);
      if (!pathValidation.isValid) {
        developer.log('Invalid file path generated: $filePath');
        return null;
      }

      // Verificar que no excedamos límites de almacenamiento
      final existingFiles = await getSavedPhotos();
      if (existingFiles.length > 1000) { // Límite de seguridad
        developer.log('Storage limit reached, cleaning old files');
        // Eliminar archivos más antiguos si es necesario
        await _cleanOldFiles(existingFiles, 900);
      }

      // Capturar foto con timeout de seguridad
      final XFile photo = await _controller!.takePicture();

      // Verificar tamaño del archivo por seguridad
      final File tempFile = File(photo.path);
      final int fileSize = await tempFile.length();
      if (fileSize > 10 * 1024 * 1024) { // Límite de 10MB
        await tempFile.delete();
        developer.log('File too large: ${fileSize} bytes');
        return null;
      }

      // Copiar archivo a ubicación permanente
      await tempFile.copy(filePath);

      // Eliminar archivo temporal de forma segura
      await tempFile.delete();

      developer.log('Photo captured successfully: $filePath (${fileSize} bytes)');
      return filePath;
    } catch (e) {
      developer.log('Error capturing photo: $e', level: 1000);
      return null;
    }
  }

  /// Limpia archivos antiguos cuando se alcanza el límite de almacenamiento
  Future<void> _cleanOldFiles(List<File> files, int maxFiles) async {
    if (files.length <= maxFiles) return;

    try {
      // Ordenar por fecha de modificación (más antiguos primero)
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      // Eliminar archivos más antiguos
      final filesToDelete = files.take(files.length - maxFiles);
      for (final file in filesToDelete) {
        await file.delete();
      }

      developer.log('Cleaned ${filesToDelete.length} old files');
    } catch (e) {
      developer.log('Error cleaning old files: $e', level: 1000);
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
