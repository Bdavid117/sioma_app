import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/enhanced_identification_service.dart';
import '../services/identification_service.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import '../models/custom_event.dart';
import '../utils/app_logger.dart';
import '../providers/service_providers.dart';

import 'dart:io';
import 'dart:async';

/// Pantalla fusionada de identificación en tiempo real con cámara completa
/// Combina funcionalidades de identificación manual y scanner automático
class AdvancedIdentificationScreen extends ConsumerStatefulWidget {
  const AdvancedIdentificationScreen({super.key});

  @override
  ConsumerState<AdvancedIdentificationScreen> createState() => _AdvancedIdentificationScreenState();
}

class _AdvancedIdentificationScreenState extends ConsumerState<AdvancedIdentificationScreen> {
  late final CameraService _cameraService;
  late final EnhancedIdentificationService _enhancedIdentificationService;
  late final IdentificationService _identificationService;
  late final DatabaseService _dbService;

  // Estados principales
  bool _isScanning = false;
  bool _isInitialized = false;
  bool _isAutoMode = false; // false = manual identification (por defecto), true = auto scanner
  
  // Datos de identificación
  Person? _identifiedPerson;
  double _confidence = 0.0;
  String _statusMessage = 'Inicializando...';
  
  // Control de scanner automático
  Timer? _scanTimer;
  int _consecutiveDetections = 0;
  Person? _lastDetectedPerson;
  
  // Estadísticas del scanner
  int _framesProcessed = 0;
  int _facesDetected = 0;
  
  // Configuración optimizada
  static const Duration _scanInterval = Duration(milliseconds: 600);
  static const double _threshold = 0.60; // Umbral base con adaptación automática según calidad ML Kit
  static const int _minConsecutiveDetections = 2;

  // Lista de personas registradas en cache
  List<Person> _registeredPersons = [];

  @override
  void initState() {
    super.initState();
    _cameraService = ref.read(cameraServiceProvider);
    _enhancedIdentificationService = ref.read(enhancedIdentificationServiceProvider);
    _identificationService = ref.read(identificationServiceProvider);
    _dbService = ref.read(databaseServiceProvider);
    
    _initializeSystem();
  }

  @override
  void dispose() {
    // Asegura detener el escaneo sin solicitar reconstrucción de UI
    _stopScanning(fromDispose: true);
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initializeSystem() async {
    setState(() {
      _statusMessage = 'Inicializando sistema...';
    });

    try {
      // Cargar personas registradas
      setState(() {
        _statusMessage = 'Cargando personas registradas...';
      });
      
      _registeredPersons = await _dbService.getAllPersons();
      
      if (_registeredPersons.isEmpty) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Sin personas registradas - Registre personas primero';
        });
        return;
      }

      // Inicializar cámara
      setState(() {
        _statusMessage = 'Inicializando cámara...';
      });
      
      final cameraInit = await _cameraService.initialize();
      if (!cameraInit) {
        setState(() {
          _statusMessage = 'Error: No se pudo inicializar la cámara';
        });
        
        // Mostrar dialog con opciones
        _showCameraErrorDialog();
        return;
      }

      // Inicializar servicio de identificación
      setState(() {
        _statusMessage = 'Inicializando reconocimiento facial...';
      });
      
      final identificationInit = await _identificationService.initialize();
      if (!identificationInit) {
        setState(() {
          _statusMessage = 'Error: No se pudo inicializar el reconocimiento facial';
        });
        return;
      }

      // Todo inicializado correctamente
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Sistema listo - ${_registeredPersons.length} personas registradas\nToca el botón para identificar persona';
      });

      // Iniciar en modo manual por defecto (no auto-scanning)
      if (_isAutoMode) {
        _startAutoScanning();
      }
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error de inicialización: $e';
      });
      
      // Log detallado del error
      AppLogger.error('Error detallado en inicialización', error: e);
    }
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error de Cámara'),
        content: const Text(
          'No se pudo acceder a la cámara. Por favor:\n\n'
          '• Verifique que la aplicación tenga permisos de cámara\n'
          '• Asegúrese de que ninguna otra app esté usando la cámara\n'
          '• Reinicie la aplicación si es necesario'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Volver al menú principal
            },
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryInitialization();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isInitialized = false;
      _isScanning = false;
    });
    
    // Limpiar recursos existentes
    await _cameraService.dispose();
    _stopScanning();
    
    // Esperar un momento antes de reintentar
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reintentar inicialización
    await _initializeSystem();
  }

  void _showEventRegistrationDialog(Person person) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar Evento - ${person.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Qué tipo de evento desea registrar para ${person.name}?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _registerEntryEvent(person);
                  },
                  icon: const Icon(Icons.login, color: Colors.green),
                  label: const Text('ENTRADA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _registerExitEvent(person);
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('SALIDA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showUnregisteredPersonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Persona No Registrada'),
        content: const Text(
          'Esta persona no está registrada en el sistema.\n\n'
          '¿Desea registrarla ahora?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Navegar a la pantalla de registro (índice 2 en NavigationBar)
              if (mounted) {
                // Encontrar el MainNavigationScreen y cambiar a la pestaña de Registro
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Registrar Persona'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerEntryEvent(Person person) async {
    try {
      final event = CustomEvent.entrada(
        personId: person.id!,
        personName: person.name,
        personDocument: person.documentId,
        location: 'finca_principal',
        notes: 'Entrada registrada desde identificación biométrica',
      );

      await _dbService.insertCustomEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Entrada registrada para ${person.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar entrada: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _registerExitEvent(Person person) async {
    try {
      final event = CustomEvent.salida(
        personId: person.id!,
        personName: person.name,
        personDocument: person.documentId,
        location: 'finca_principal',
        notes: 'Salida registrada desde identificación biométrica',
      );

      await _dbService.insertCustomEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Salida registrada para ${person.name}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar salida: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDiagnosticInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Diagnóstico'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagnosticRow('Estado del Sistema', _isInitialized ? 'Inicializado' : 'No Inicializado'),
              _buildDiagnosticRow('Estado de Cámara', _cameraService.isInitialized ? 'OK' : 'Error'),
              _buildDiagnosticRow('Personas Registradas', '${_registeredPersons.length}'),
              _buildDiagnosticRow('Modo Actual', _isAutoMode ? 'Automático' : 'Manual'),
              _buildDiagnosticRow('Estado de Escaneo', _isScanning ? 'Activo' : 'Inactivo'),
              _buildDiagnosticRow('Mensaje Actual', _statusMessage),
              _buildDiagnosticRow('Cámaras Disponibles', '${_cameraService.cameras.length}'),
              if (_cameraService.cameras.isNotEmpty)
                ..._cameraService.cameras.asMap().entries.map((entry) =>
                  _buildDiagnosticRow(
                    'Cámara ${entry.key + 1}',
                    '${entry.value.name} (${entry.value.lensDirection})'
                  )
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryInitialization();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _startAutoScanning() {
    if (!_cameraService.isInitialized) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanner activo - Buscando rostros...';
      _framesProcessed = 0;
      _facesDetected = 0;
    });

    AppLogger.info('🚀 Iniciando Auto Scanner con Enhanced Identification');

    // Usar Timer para escaneo continuo con EnhancedIdentificationService
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isScanning || !_isAutoMode) {
        timer.cancel();
        return;
      }

      try {
        // Capturar frame
        final imagePath = await _cameraService.takePicture();
        if (imagePath == null) return;

        _framesProcessed++;

        // Usar EnhancedIdentificationService (con ML Kit boost)
        final result = await _enhancedIdentificationService.identifyPersonWithMLKit(
          imagePath,
          threshold: _threshold,
          strictMode: false,
        );

        if (!mounted) return;

        if (result.identified && result.person != null) {
          // PERSONA IDENTIFICADA ✅
          setState(() {
            _identifiedPerson = result.person;
            _confidence = result.confidence ?? 0.0;
            _facesDetected++;
            _statusMessage = '✅ ${result.person!.name} - ${(_confidence * 100).toStringAsFixed(1)}%';
          });

          AppLogger.info('✅ AUTO: ${result.person!.name} identificado (${(_confidence * 100).toStringAsFixed(1)}%)');

          // Mostrar diálogo de registro de evento
          _showEventRegistrationDialog(result.person!);

          // Auto-limpiar después de 5 segundos
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _isAutoMode) {
              setState(() {
                _identifiedPerson = null;
                _confidence = 0.0;
                _statusMessage = 'Escaneando... ($_framesProcessed frames, $_facesDetected rostros)';
              });
            }
          });
        } else {
          // No identificado
          setState(() {
            _statusMessage = '🔍 Buscando rostro... ($_framesProcessed frames procesados)';
          });
        }

        // Limpiar imagen temporal
        try {
          await File(imagePath).delete();
        } catch (e) {
          // Ignorar error de limpieza
        }
      } catch (e) {
        AppLogger.error('Error en auto scanner', error: e);
      }
    });
  }

  void _stopScanning({bool fromDispose = false}) {
    // Detener el timer y limpiar estados sin reconstruir la UI si estamos en dispose
    _scanTimer?.cancel();
    _scanTimer = null;
    _isScanning = false;
    _isAutoMode = false; // Garantiza que no se reinicie el loop
    _consecutiveDetections = 0;
    _lastDetectedPerson = null;

    // No llamar setState durante dispose para evitar "_ElementLifecycle.defunct"
    // En escenarios normales, la UI relevante se actualiza donde se invoca _stopScanning
    if (!fromDispose && mounted) {
      // Actualización opcional y segura (mínima). Evitamos forzar animaciones innecesarias.
      // setState(() {});
    }

    AppLogger.info('🛑 Scanner detenido - Frames procesados: $_framesProcessed, Rostros: $_facesDetected');
  }

  Future<void> _performQuickScan() async {
    try {
      // Captura rápida
      final imagePath = await _cameraService.takePicture();
      if (imagePath == null) return;

      // Identificación mejorada con ML Kit
      final result = await _enhancedIdentificationService.identifyPersonWithMLKit(
        imagePath,
        threshold: _threshold,
        strictMode: false,
      );

      if (result.identified) {
        final person = result.person!;
        
        // Verificar detecciones consecutivas
        if (_lastDetectedPerson?.id == person.id) {
          _consecutiveDetections++;
        } else {
          _consecutiveDetections = 1;
          _lastDetectedPerson = person;
        }

        // Solo mostrar si hay suficientes detecciones consecutivas
        if (_consecutiveDetections >= _minConsecutiveDetections) {
          setState(() {
            _identifiedPerson = person;
            _confidence = result.confidence ?? 0.0;
            _statusMessage = 'Persona identificada';
          });

          // Auto-limpiar después de 3 segundos
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isAutoMode) {
              setState(() {
                _identifiedPerson = null;
                _confidence = 0.0;
                _statusMessage = 'Escaneando...';
              });
            }
          });
        }
      } else {
        _consecutiveDetections = 0;
        _lastDetectedPerson = null;
      }

      // Limpiar archivo temporal
      try {
        await File(imagePath).delete();
      } catch (e) {
        // Ignorar errores de limpieza
      }
    } catch (e) {
      // Manejar errores silenciosamente en modo auto
    }
  }

  Future<void> _performManualIdentification() async {
    setState(() {
      _statusMessage = 'Capturando imagen...';
      _identifiedPerson = null;
    });

    try {
      final imagePath = await _cameraService.takePicture();
      if (imagePath == null) {
        setState(() {
          _statusMessage = 'Error: No se pudo capturar la imagen';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Comparando con ${_registeredPersons.length} personas registradas...';
      });

      final result = await _enhancedIdentificationService.identifyPersonWithMLKit(
        imagePath,
        threshold: _threshold,
        strictMode: false,
      );

      if (result.identified) {
        final person = result.person!;
        final confidence = result.confidence ?? 0.0;
        
        setState(() {
          _identifiedPerson = person;
          _confidence = confidence;
          _statusMessage = '✅ PERSONA REGISTRADA\nCoincidencia: ${(confidence * 100).toStringAsFixed(1)}%';
        });

        // Mostrar opción para registrar evento de entrada/salida
        _showEventRegistrationDialog(person);
      } else {
        setState(() {
          _identifiedPerson = null;
          _confidence = 0.0;
          _statusMessage = '❌ PERSONA NO REGISTRADA\nNo se encontró en la base de datos';
        });

        // Opción para registrar nueva persona
        _showUnregisteredPersonDialog();
      }

      // Limpiar archivo temporal después de un tiempo
      Future.delayed(const Duration(seconds: 30), () async {
        try {
          await File(imagePath).delete();
        } catch (e) {
          // Ignorar errores de limpieza
        }
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Error durante el análisis: $e';
      });
      BiometricLogger.error('Error en identificación manual', e);
    }
  }

  void _toggleMode() {
    setState(() {
      _isAutoMode = !_isAutoMode;
      _identifiedPerson = null;
      _confidence = 0.0;
    });

    if (_isAutoMode) {
      _startAutoScanning();
    } else {
      _stopScanning();
      setState(() {
        _statusMessage = 'Modo manual - Toca para identificar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cámara en pantalla completa
          _buildFullScreenCamera(),
          
          // Overlay de información
          _buildInfoOverlay(),
          
          // Controles superiores
          _buildTopControls(),
          
          // Controles inferiores
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildFullScreenCamera() {
    if (!_isInitialized || !_cameraService.isInitialized) {
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (_statusMessage.contains('Error')) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryInitialization,
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller;
    if (controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Error: Controlador de cámara no disponible',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(controller),
    );
  }

  Widget _buildInfoOverlay() {
    if (_identifiedPerson == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(230),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _identifiedPerson!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Doc: ${_identifiedPerson!.documentId}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Confianza: ${(_confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de volver
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          
          // Indicador de modo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isAutoMode 
                  ? Colors.green.withAlpha(204)
                  : Colors.blue.withAlpha(204),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAutoMode ? Icons.auto_awesome : Icons.touch_app,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isAutoMode ? 'AUTO' : 'MANUAL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Botones de control
          Row(
            children: [
              // Botón de diagnóstico
              if (!_isInitialized || _statusMessage.contains('Error'))
                IconButton(
                  onPressed: _showDiagnosticInfo,
                  icon: const Icon(Icons.info_outline, color: Colors.orange),
                ),
              
              // Botón de cambio de modo
              IconButton(
                onPressed: _toggleMode,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAutoMode ? Icons.pan_tool : Icons.auto_awesome,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Estado del sistema
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(179),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Indicador de estado del sistema
          if (!_isInitialized)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusMessage.contains('Error') 
                    ? Colors.red.withAlpha(204)
                    : Colors.orange.withAlpha(204),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage.contains('Error') ? 'ERROR' : 'INICIALIZANDO',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Botón de acción (solo en modo manual)
          if (!_isAutoMode && _isInitialized)
            GestureDetector(
              onTap: _performManualIdentification,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}