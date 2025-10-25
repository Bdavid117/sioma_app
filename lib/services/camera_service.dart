import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../utils/validation_utils.dart';
import '../utils/app_logger.dart';

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
      CameraLogger.info('Iniciando inicialización de cámara...');
      
      // Limpiar recursos previos si existen
      if (_controller != null) {
        await dispose();
      }

      // Solicitar permisos
      CameraLogger.info('Solicitando permisos de cámara...');
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission != PermissionStatus.granted) {
        CameraLogger.warning('Permiso de cámara denegado: $cameraPermission');
        throw Exception('Permiso de cámara denegado. Por favor active los permisos en configuración.');
      }

      // Obtener cámaras disponibles
      CameraLogger.info('Obteniendo cámaras disponibles...');
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        CameraLogger.warning('No se encontraron cámaras disponibles');
        throw Exception('No hay cámaras disponibles en este dispositivo');
      }

      CameraLogger.info('Cámaras encontradas: ${_cameras.length}');
      for (int i = 0; i < _cameras.length; i++) {
        CameraLogger.debug('Cámara $i: ${_cameras[i].name} - ${_cameras[i].lensDirection}');
      }

      // Buscar cámara frontal (preferida para reconocimiento facial)
      CameraDescription selectedCamera = _cameras.first;
      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }

      CameraLogger.info('Cámara seleccionada: ${selectedCamera.name} (${selectedCamera.lensDirection})');

      // Inicializar controlador
      CameraLogger.info('Inicializando controlador de cámara...');
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false, // No necesitamos audio
      );

      await _controller!.initialize();
      
      if (!_controller!.value.isInitialized) {
        throw Exception('El controlador de cámara no se inicializó correctamente');
      }

      _isInitialized = true;
      CameraLogger.info('Cámara inicializada exitosamente');

      return true;
    } catch (e) {
      CameraLogger.error('Error al inicializar cámara', e);
      _isInitialized = false;
      
      // Limpiar recursos en caso de error
      try {
        await _controller?.dispose();
        _controller = null;
      } catch (disposeError) {
        CameraLogger.warning('Error al limpiar recursos: $disposeError');
      }
      
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
      CameraLogger.error('Error al cambiar cámara', e);
      return false;
    }
  }

  /// Captura una foto y la guarda en almacenamiento local con validaciones de seguridad
  Future<String?> takePicture({String? fileName}) async {
    if (!_isInitialized || _controller == null) {
      CameraLogger.warning('Camera not initialized or controller is null');
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
        CameraLogger.warning('Invalid file path generated: $filePath');
        return null;
      }

      // Verificar que no excedamos límites de almacenamiento
      final existingFiles = await getSavedPhotos();
      if (existingFiles.length > 1000) { // Límite de seguridad
        CameraLogger.info('Storage limit reached, cleaning old files');
        // Eliminar archivos más antiguos si es necesario
        await _cleanOldFiles(existingFiles, 900);
      }

      // Capturar foto de forma optimizada
      final XFile photo = await _controller!.takePicture();

      // Mover archivo directamente (más rápido que copiar)
      final File tempFile = File(photo.path);
      final int fileSize = await tempFile.length();
      
      // Verificación rápida de tamaño
      if (fileSize > 10 * 1024 * 1024) { // Límite de 10MB
        await tempFile.delete();
        CameraLogger.warning('File too large: ${fileSize} bytes');
        return null;
      }

      // Mover archivo en lugar de copiar (más eficiente)
      final File finalFile = await tempFile.rename(filePath);
      
      // Verificar que el archivo se movió correctamente
      if (!(await finalFile.exists())) {
        CameraLogger.warning('Failed to move file to final location');
        return null;
      }

      CameraLogger.info('Photo captured successfully: $filePath (${fileSize} bytes)');
      return filePath;
    } catch (e) {
      CameraLogger.error('Error capturing photo', e);
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

      CameraLogger.info('Cleaned ${filesToDelete.length} old files');
    } catch (e) {
      CameraLogger.error('Error cleaning old files', e);
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

  /// Libera los recursos de la cámara de forma segura
  Future<void> dispose() async {
    if (_controller != null) {
      try {
        // Agregar delay para evitar crashes del plugin
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Verificar si aún está inicializado antes de dispose
        if (_controller!.value.isInitialized) {
          await _controller!.dispose();
        }
        _controller = null;
      } catch (e) {
        // Log del error pero no propagar para evitar crashes
        CameraLogger.warning('Error disposing camera controller: $e');
        _controller = null;
      }
    }
    _isInitialized = false;
  }

  /// Disposición segura sin espera (para uso en dispose de widgets)
  void disposeSync() {
    if (_controller != null) {
      Future.microtask(() async {
        try {
          await dispose();
        } catch (e) {
          CameraLogger.warning('Error in async dispose: $e');
        }
      });
    }
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
      CameraLogger.error('Error al obtener fotos', e);
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
      CameraLogger.error('Error al eliminar foto', e);
      return false;
    }
  }
}
