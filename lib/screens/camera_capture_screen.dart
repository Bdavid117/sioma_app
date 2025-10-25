import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../utils/app_logger.dart';
import 'dart:io';

/// Pantalla para capturar fotos de rostro usando la cámara
class CameraCaptureScreen extends StatefulWidget {
  final String? personName;
  final String? documentId;
  final Function(String photoPath)? onPhotoTaken;

  const CameraCaptureScreen({
    super.key,
    this.personName,
    this.documentId,
    this.onPhotoTaken,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final CameraService _cameraService = CameraService();
  bool _isLoading = true;
  String _statusMessage = 'Inicializando cámara...';
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Inicializando cámara...';
    });

    final success = await _cameraService.initialize();

    setState(() {
      _isLoading = false;
      if (success) {
        _statusMessage = 'Cámara lista - ${_cameraService.getCurrentCameraInfo()}';
      } else {
        _statusMessage = 'Error: No se pudo inicializar la cámara';
      }
    });
  }

  Future<void> _takePicture() async {
    if (!_cameraService.isInitialized) return;

    setState(() {
      _statusMessage = 'Capturando foto...';
    });

    try {
      final String? photoPath = await _cameraService.takePicture();

      if (photoPath != null) {
        setState(() {
          _statusMessage = 'Foto capturada exitosamente';
        });

        // NO ejecutar callback aquí - evita duplicación
        // Solo mostrar preview para confirmación del usuario
        _showPhotoPreview(photoPath);
      } else {
        setState(() {
          _statusMessage = 'Error al capturar la foto';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (!_cameraService.hasMultipleCameras()) return;

    setState(() {
      _statusMessage = 'Cambiando cámara...';
    });

    final success = await _cameraService.switchCamera();

    setState(() {
      if (success) {
        _statusMessage = 'Cámara cambiada - ${_cameraService.getCurrentCameraInfo()}';
      } else {
        _statusMessage = 'Error al cambiar cámara';
      }
    });
  }

  void _showPhotoPreview(String photoPath) {
    showDialog(
      context: context,
      barrierDismissible: false, // Evitar cierre accidental
      builder: (context) => AlertDialog(
        title: const Text('Foto Capturada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photoPath),
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(seconds: 1),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (widget.personName != null) ...[
              Text('Persona: ${widget.personName}'),
              const SizedBox(height: 8),
            ],
            if (widget.documentId != null) ...[
              Text('Documento: ${widget.documentId}'),
              const SizedBox(height: 8),
            ],
            Text('Guardada en: ${photoPath.split('/').last}'),
            const SizedBox(height: 8),
            const Text(
              '¿Desea usar esta foto?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar dialog primero
              
              // Mostrar indicador de procesamiento
              setState(() {
                _statusMessage = 'Procesando foto...';
              });
              
              // Ejecutar callback SOLO cuando el usuario confirma
              if (widget.onPhotoTaken != null) {
                widget.onPhotoTaken!(photoPath);
              }
              
              // Cerrar cámara de forma segura
              try {
                _cameraService.disposeSync();
              } catch (e) {
                CameraLogger.warning('Error disposing camera: $e');
              }
              
              // Retornar con delay mínimo para evitar congelamiento
              await Future.delayed(const Duration(milliseconds: 50));
              if (mounted) {
                Navigator.pop(context, photoPath);
              }
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('Usar Esta Foto'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.orange),
                SizedBox(width: 8),
                Text('Tomar Otra'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isLoading || !_cameraService.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Preview de la cámara
        CameraPreview(_cameraService.controller!),

        // Overlay con guías para el rostro
        CustomPaint(
          painter: FaceGuidePainter(),
          size: Size.infinite,
        ),

        // Información en la parte superior
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (widget.personName != null) ...[
                  Text(
                    widget.personName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (widget.documentId != null) ...[
                  Text(
                    'Doc: ${widget.documentId}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Coloca tu rostro dentro del marco',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Mensaje de estado en la parte inferior
        Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      height: 100,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botón cambiar cámara
          if (_cameraService.hasMultipleCameras())
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(
                Icons.cameraswitch,
                color: Colors.white,
                size: 32,
              ),
              tooltip: 'Cambiar Cámara',
            )
          else
            const SizedBox(width: 48),

          // Botón capturar
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.black,
                size: 32,
              ),
            ),
          ),

          // Botón cerrar
          IconButton(
            onPressed: () async {
              // Cerrar cámara de forma segura antes de salir
              try {
                _cameraService.disposeSync();
              } catch (e) {
                CameraLogger.warning('Error disposing camera: $e');
              }
              
              // Delay para permitir que la cámara se cierre correctamente
              await Future.delayed(const Duration(milliseconds: 200));
              if (mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Cancelar',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCameraPreview()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Disposición segura de la cámara para prevenir crashes
    Future.microtask(() async {
      try {
        await _cameraService.dispose();
      } catch (e) {
        // Silenciosamente manejar errores de disposición
        CameraLogger.warning('Error disposing camera: $e');
      }
    });
    super.dispose();
  }
}

/// Painter personalizado para dibujar guías del rostro
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Calcular dimensiones del marco del rostro
    final double frameWidth = size.width * 0.6;
    final double frameHeight = frameWidth * 1.2; // Proporción típica de rostro
    final double left = (size.width - frameWidth) / 2;
    final double top = (size.height - frameHeight) / 2;

    // Dibujar marco oval para el rostro
    final Rect faceRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);
    canvas.drawOval(faceRect, paint);

    // Dibujar esquinas del marco
    final double cornerLength = 30;
    final Paint cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Esquina superior izquierda
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Esquina superior derecha
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top),
      Offset(left + frameWidth, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top),
      Offset(left + frameWidth, top + cornerLength),
      cornerPaint,
    );

    // Esquina inferior izquierda
    canvas.drawLine(
      Offset(left, top + frameHeight - cornerLength),
      Offset(left, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + frameHeight),
      Offset(left + cornerLength, top + frameHeight),
      cornerPaint,
    );

    // Esquina inferior derecha
    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
