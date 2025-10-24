import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
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
  String? _lastCapturedPhoto;

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
          _lastCapturedPhoto = photoPath;
          _statusMessage = 'Foto capturada exitosamente';
        });

        // Callback opcional para notificar que se tomó una foto
        if (widget.onPhotoTaken != null) {
          widget.onPhotoTaken!(photoPath);
        }

        // Mostrar preview de la foto capturada
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, photoPath); // Retornar ruta de la foto
            },
            child: const Text('Usar Esta Foto'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tomar Otra'),
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
            onPressed: () => Navigator.pop(context),
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
    _cameraService.dispose();
    super.dispose();
  }
}

/// Painter personalizado para dibujar guías del rostro
class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
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
