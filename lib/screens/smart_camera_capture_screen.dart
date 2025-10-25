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
  static const int _requiredGoodFrames = 2; // Reducido de 3 a 2 para captura más rápida
  
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
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cameraService.hasMultipleCameras())
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
              onPressed: () async {
                _stopQualityMonitoring();
                await _cameraService.switchCamera();
                if (_autoModeEnabled) {
                  _startQualityMonitoring();
                }
              },
            ),
          IconButton(
            icon: Icon(
              _autoModeEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: _autoModeEnabled ? Colors.greenAccent : Colors.white,
              size: 28,
            ),
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // Cámara a PANTALLA COMPLETA
                if (_cameraService.isInitialized)
                  Positioned.fill(
                    child: CameraPreview(_cameraService.controller!),
                  )
                else
                  const Center(
                    child: Text(
                      'Cámara no disponible',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                
                // Overlay semitransparente superior
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Guía facial mejorada - más grande
                if (_cameraService.isInitialized)
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.75,
                      height: MediaQuery.of(context).size.width * 0.95,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _currentQuality?.isOptimal == true
                              ? Colors.greenAccent
                              : Colors.white.withOpacity(0.7),
                          width: _currentQuality?.isOptimal == true ? 5 : 3,
                        ),
                        borderRadius: BorderRadius.circular(200),
                        boxShadow: _currentQuality?.isOptimal == true
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                
                // Panel inferior con controles
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.95),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mensaje de estado - más prominente
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _currentQuality?.isOptimal == true
                                ? Colors.green.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: _currentQuality?.isOptimal == true
                                  ? Colors.greenAccent
                                  : Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isAnalyzing)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              if (_isAnalyzing) const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Indicadores de calidad - diseño mejorado
                        if (_currentQuality != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
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
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // Botón de captura manual - más grande y atractivo
                        if (!_autoModeEnabled)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isCapturing ? null : _captureManually,
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isCapturing
                                          ? Colors.grey
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Indicador de modo automático
                        if (_autoModeEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.greenAccent, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Modo automático: $_goodQualityCount/$_requiredGoodFrames frames',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
        ),
      ],
    );
  }
}
