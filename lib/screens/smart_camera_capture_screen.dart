import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/photo_quality_analyzer.dart';
import '../providers/service_providers.dart';
import '../utils/app_logger.dart';
import 'dart:io';
import 'dart:async';

/// Pantalla de captura inteligente con análisis automático de calidad
class SmartCameraCaptureScreen extends ConsumerStatefulWidget {
  final String? personName;
  final String? documentId;
  final Function(String photoPath)? onPhotoTaken;
  final bool autoCapture;

  const SmartCameraCaptureScreen({
    super.key,
    this.personName,
    this.documentId,
    this.onPhotoTaken,
    this.autoCapture = true,
  });

  @override
  ConsumerState<SmartCameraCaptureScreen> createState() => _SmartCameraCaptureScreenState();
}

class _SmartCameraCaptureScreenState extends ConsumerState<SmartCameraCaptureScreen> {
  late final CameraService _cameraService;
  late final PhotoQualityAnalyzer _qualityAnalyzer;
  
  bool _isLoading = true;
  String _statusMessage = 'Inicializando cámara inteligente...';
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  
  // Análisis de calidad en tiempo real
  Timer? _qualityCheckTimer;
  PhotoQualityResult? _currentQuality;
  int _goodQualityCount = 0;
  static const int _requiredGoodFrames = 3; // Requiere 3 frames consecutivos de buena calidad
  
  // Captura automática
  bool _autoModeEnabled = true;
  List<String> _capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    _cameraService = ref.read(cameraServiceProvider);
    _qualityAnalyzer = ref.read(photoQualityAnalyzerProvider);
    _autoModeEnabled = widget.autoCapture;
    _initializeCamera();
  }

  @override
  void dispose() {
    _qualityCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '🎥 Inicializando cámara...';
    });

    final success = await _cameraService.initialize();

    setState(() {
      _isLoading = false;
      if (success) {
        _statusMessage = '✅ Cámara lista';
        if (_autoModeEnabled) {
          _startQualityMonitoring();
        }
      } else {
        _statusMessage = '❌ Error: No se pudo inicializar la cámara';
      }
    });
  }

  /// Inicia el monitoreo de calidad en tiempo real
  void _startQualityMonitoring() {
    _qualityCheckTimer?.cancel();
    _qualityCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500), // Analizar cada 500ms
      (_) => _analyzeCurrentFrame(),
    );
    
    setState(() {
      _statusMessage = '📸 Posiciona tu rostro frente a la cámara...';
    });
  }

  /// Detiene el monitoreo de calidad
  void _stopQualityMonitoring() {
    _qualityCheckTimer?.cancel();
  }

  /// Analiza el frame actual de la cámara
  Future<void> _analyzeCurrentFrame() async {
    if (!_cameraService.isInitialized || _isCapturing || _isAnalyzing) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Capturar frame temporal para análisis
      final tempPath = await _cameraService.takePicture();
      
      if (tempPath == null) {
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Analizar calidad
      final quality = await _qualityAnalyzer.analyzePhoto(tempPath);
      
      setState(() {
        _currentQuality = quality;
        _isAnalyzing = false;
      });

      // Actualizar UI con feedback
      _updateStatusMessage(quality);

      // Si la calidad es óptima, incrementar contador
      if (quality.isOptimal) {
        _goodQualityCount++;
        
        // Si tenemos suficientes frames buenos consecutivos, capturar automáticamente
        if (_goodQualityCount >= _requiredGoodFrames && _autoModeEnabled) {
          _stopQualityMonitoring();
          await _captureOptimalPhoto(tempPath);
        }
      } else {
        _goodQualityCount = 0; // Resetear si no es óptimo
        // Eliminar frame temporal de baja calidad
        try {
          await File(tempPath).delete();
        } catch (e) {
          CameraLogger.debug('No se pudo eliminar frame temporal: $e');
        }
      }
      
    } catch (e) {
      CameraLogger.error('Error analizando frame', e);
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  /// Actualiza el mensaje de estado según la calidad
  void _updateStatusMessage(PhotoQualityResult quality) {
    String message = '';
    
    if (quality.isOptimal) {
      message = '✨ Excelente! Calidad: ${(quality.qualityScore * 100).toStringAsFixed(0)}%';
      if (_goodQualityCount > 0) {
        message += ' ($_goodQualityCount/$_requiredGoodFrames)';
      }
    } else {
      // Mostrar la recomendación más importante
      if (quality.recommendations.isNotEmpty) {
        message = quality.recommendations.first;
      } else {
        message = '⚠️ Calidad: ${quality.qualityLevel} (${(quality.qualityScore * 100).toStringAsFixed(0)}%)';
      }
    }
    
    setState(() {
      _statusMessage = message;
    });
  }

  /// Captura la foto óptima detectada automáticamente
  Future<void> _captureOptimalPhoto(String photoPath) async {
    setState(() {
      _isCapturing = true;
      _statusMessage = '📸 ¡Captura automática! Foto óptima detectada';
    });

    await Future.delayed(const Duration(milliseconds: 300));

    _capturedPhotos.add(photoPath);
    
    // Mostrar preview con análisis de calidad
    _showPhotoPreview(photoPath, _currentQuality!);
  }

  /// Captura manual (modo de respaldo)
  Future<void> _captureManually() async {
    if (!_cameraService.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _statusMessage = '📸 Capturando...';
    });

    try {
      final photoPath = await _cameraService.takePicture();
      
      if (photoPath != null) {
        // Analizar calidad de la foto manual
        final quality = await _qualityAnalyzer.analyzePhoto(photoPath);
        
        _capturedPhotos.add(photoPath);
        _showPhotoPreview(photoPath, quality);
      } else {
        setState(() {
          _isCapturing = false;
          _statusMessage = '❌ Error al capturar';
        });
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _statusMessage = '❌ Error: $e';
      });
    }
  }

  void _showPhotoPreview(String photoPath, PhotoQualityResult quality) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('Foto Capturada'),
            const SizedBox(width: 8),
            Icon(
              quality.isOptimal ? Icons.check_circle : Icons.warning,
              color: quality.isOptimal ? Colors.green : Colors.orange,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview de la foto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(photoPath),
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              
              // Análisis de calidad
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: quality.isOptimal ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: quality.isOptimal ? Colors.green : Colors.orange,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Calidad: ${quality.qualityLevel}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: quality.isOptimal ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Score: ${(quality.qualityScore * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 4),
                    Text('Nitidez: ${(quality.sharpnessScore * 100).toStringAsFixed(0)}%', 
                      style: const TextStyle(fontSize: 12)),
                    Text('Iluminación: ${(quality.brightnessScore * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12)),
                    Text('Contraste: ${(quality.contrastScore * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              
              if (quality.recommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...quality.recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(rec, style: const TextStyle(fontSize: 12)),
                )),
              ],
              
              const SizedBox(height: 16),
              if (widget.personName != null)
                Text('Persona: ${widget.personName}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (widget.documentId != null)
                Text('Documento: ${widget.documentId}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Rechazar foto
              try {
                await File(photoPath).delete();
                _capturedPhotos.remove(photoPath);
              } catch (e) {
                CameraLogger.error('Error eliminando foto', e);
              }
              
              if (mounted) {
                Navigator.of(context).pop();
                setState(() {
                  _isCapturing = false;
                  _goodQualityCount = 0;
                });
                
                if (_autoModeEnabled) {
                  _startQualityMonitoring();
                }
              }
            },
            child: const Text('Rechazar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              if (widget.onPhotoTaken != null) {
                widget.onPhotoTaken!(photoPath);
              }
              
              if (mounted) {
                Navigator.of(context).pop(photoPath);
              }
            },
            child: const Text('Usar Esta Foto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura Inteligente'),
        actions: [
          if (_cameraService.hasMultipleCameras())
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: () async {
                _stopQualityMonitoring();
                await _cameraService.switchCamera();
                if (_autoModeEnabled) {
                  _startQualityMonitoring();
                }
              },
              tooltip: 'Cambiar cámara',
            ),
          IconButton(
            icon: Icon(_autoModeEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined),
            onPressed: () {
              setState(() {
                _autoModeEnabled = !_autoModeEnabled;
                if (_autoModeEnabled) {
                  _startQualityMonitoring();
                } else {
                  _stopQualityMonitoring();
                }
              });
            },
            tooltip: _autoModeEnabled ? 'Modo Auto' : 'Modo Manual',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Preview de cámara
                Expanded(
                  child: Stack(
                    children: [
                      if (_cameraService.isInitialized)
                        Center(
                          child: AspectRatio(
                            aspectRatio: _cameraService.controller!.value.aspectRatio,
                            child: CameraPreview(_cameraService.controller!),
                          ),
                        )
                      else
                        const Center(child: Text('Cámara no disponible')),
                      
                      // Overlay con guía facial
                      if (_cameraService.isInitialized)
                        Center(
                          child: Container(
                            width: 250,
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _currentQuality?.isOptimal == true
                                    ? Colors.green
                                    : Colors.white.withOpacity(0.5),
                                width: _currentQuality?.isOptimal == true ? 4 : 2,
                              ),
                              borderRadius: BorderRadius.circular(150),
                            ),
                          ),
                        ),
                      
                      // Indicador de análisis
                      if (_isAnalyzing)
                        const Positioned(
                          top: 16,
                          right: 16,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Panel de información y controles
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mensaje de estado
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Indicadores de calidad
                      if (_currentQuality != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQualityIndicator(
                              '💡',
                              'Luz',
                              _currentQuality!.brightnessScore,
                            ),
                            _buildQualityIndicator(
                              '🎯',
                              'Nitidez',
                              _currentQuality!.sharpnessScore,
                            ),
                            _buildQualityIndicator(
                              '🎨',
                              'Contraste',
                              _currentQuality!.contrastScore,
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Botón de captura manual
                      if (!_autoModeEnabled || !_cameraService.isInitialized)
                        ElevatedButton.icon(
                          onPressed: _isCapturing ? null : _captureManually,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capturar Foto'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      
                      if (_autoModeEnabled)
                        Text(
                          'Modo automático: ${_goodQualityCount}/$_requiredGoodFrames frames óptimos',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQualityIndicator(String emoji, String label, double score) {
    final color = score >= 0.7
        ? Colors.green
        : score >= 0.5
            ? Colors.orange
            : Colors.red;
    
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Text(
          '${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
