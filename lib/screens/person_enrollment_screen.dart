import 'package:flutter/material.dart';
import '../services/database_service.dart';

import '../services/face_embedding_service.dart';
import '../services/identification_service.dart';
import '../models/person.dart';
import '../utils/validation_utils.dart';
import '../screens/smart_camera_capture_screen.dart';
import 'dart:io';
import 'dart:convert';

/// Pantalla completa de registro (enrollment) de personas
class PersonEnrollmentScreen extends StatefulWidget {
  const PersonEnrollmentScreen({super.key});

  @override
  State<PersonEnrollmentScreen> createState() => _PersonEnrollmentScreenState();
}

class _PersonEnrollmentScreenState extends State<PersonEnrollmentScreen> {
  final DatabaseService _dbService = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final IdentificationService _identificationService = IdentificationService();

  // Controladores de formulario
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Estado del proceso de registro
  EnrollmentStep _currentStep = EnrollmentStep.personalData;
  String? _capturedPhotoPath;
  List<double>? _generatedEmbedding;
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Inicializando servicios...';
    });

    try {
      await _embeddingService.initialize();
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Servicios inicializados correctamente';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error al inicializar servicios: $e';
      });
    }
  }

  /// Valida y procesa los datos personales
  Future<void> _processPersonalData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Validando datos personales...';
    });

    try {
      // Validar datos usando ValidationUtils
      final nameValidation = ValidationUtils.validatePersonName(_nameController.text);
      if (!nameValidation.isValid) {
        _showError('Nombre inválido', nameValidation.error!);
        return;
      }

      final documentValidation = ValidationUtils.validateDocumentId(_documentController.text);
      if (!documentValidation.isValid) {
        _showError('Documento inválido', documentValidation.error!);
        return;
      }

      // Verificar si ya existe una persona con ese documento
      final existingPerson = await _dbService.getPersonByDocument(documentValidation.value!);
      if (existingPerson != null) {
        _showError('Documento duplicado', 'Ya existe una persona registrada con el documento: ${documentValidation.value}');
        return;
      }

      // Actualizar controladores con datos validados
      _nameController.text = nameValidation.value!;
      _documentController.text = documentValidation.value!;

      setState(() {
        _currentStep = EnrollmentStep.photoCapture;
        _statusMessage = 'Datos personales validados correctamente';
        _isProcessing = false;
      });
    } catch (e) {
      _showError('Error de validación', e.toString());
    }
  }

  /// Captura la foto biométrica
  Future<void> _capturePhoto() async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Abriendo cámara inteligente...';
      });

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SmartCameraCaptureScreen(
            personName: _nameController.text,
            documentId: _documentController.text,
            autoCapture: true, // Modo automático habilitado
            onPhotoTaken: (photoPath) {
              // Callback vacío para evitar duplicación
              // El procesamiento se hará cuando se retorne el result
            },
          ),
        ),
      );

      // Esperar un momento después de cerrar la cámara
      await Future.delayed(const Duration(milliseconds: 300));

      if (result != null && mounted) {
        setState(() {
          _capturedPhotoPath = result;
          _currentStep = EnrollmentStep.embeddingGeneration;
          _statusMessage = 'Foto capturada. Generando características biométricas...';
          _isProcessing = true; // Mantener indicador de procesamiento
        });

        // Generar embedding automáticamente con delay más corto
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          await _generateEmbedding();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Captura cancelada';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Error de cámara', 'No se pudo capturar la foto: $e');
    }
  }

  /// Genera el embedding facial
  Future<void> _generateEmbedding() async {
    if (_capturedPhotoPath == null) {
      _showError('Error', 'No hay foto capturada para procesar');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Generando características biométricas...';
    });

    try {
      // Registrar inicio del proceso de generación
      final startTime = DateTime.now().millisecondsSinceEpoch;
      
      final embedding = await _embeddingService.generateEmbedding(_capturedPhotoPath!);

      final processingTime = DateTime.now().millisecondsSinceEpoch - startTime;

      if (embedding != null && embedding.isNotEmpty) {
        // Registrar evento de embedding exitoso
        await _identificationService.registerAnalysisEvent(
          imagePath: _capturedPhotoPath!,
          analysisType: 'embedding_generated',
          wasSuccessful: true,
          documentId: _documentController.text,
          personName: _nameController.text,
          confidence: 1.0,
          processingTimeMs: processingTime,
          metadata: {
            'embedding_dimensions': embedding.length,
            'photo_path': _capturedPhotoPath!,
          },
        );

        if (mounted) {
          setState(() {
            _generatedEmbedding = embedding;
            _currentStep = EnrollmentStep.confirmation;
            _statusMessage = 'Características biométricas generadas correctamente (${embedding.length}D)';
            _isProcessing = false;
          });
        }
      } else {
        // Registrar evento de error en embedding
        await _identificationService.registerAnalysisEvent(
          imagePath: _capturedPhotoPath!,
          analysisType: 'embedding_failed',
          wasSuccessful: false,
          documentId: _documentController.text,
          personName: _nameController.text,
          confidence: 0.0,
          processingTimeMs: processingTime,
          metadata: {
            'error': 'Null or empty embedding returned',
            'photo_path': _capturedPhotoPath!,
          },
        );
        
        _showError('Error biométrico', 'No se pudieron generar las características biométricas de la imagen');
      }
    } catch (e) {
      // Registrar evento de excepción
      await _identificationService.registerAnalysisEvent(
        imagePath: _capturedPhotoPath ?? 'unknown',
        analysisType: 'embedding_exception',
        wasSuccessful: false,
        documentId: _documentController.text,
        personName: _nameController.text,
        confidence: 0.0,
        processingTimeMs: 0,
        metadata: {
          'error': e.toString(),
          'photo_path': _capturedPhotoPath!,
        },
      );
      
      _showError('Error de procesamiento', 'Error al procesar la imagen: $e');
    }
  }

  /// Completa el registro guardando en la base de datos
  Future<void> _completeRegistration() async {
    if (_generatedEmbedding == null || _capturedPhotoPath == null) {
      _showError('Datos incompletos', 'Faltan datos requeridos para completar el registro');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Guardando registro en la base de datos...';
    });

    try {
      // Crear objeto Person con todos los datos validados
      final person = Person(
        name: _nameController.text,
        documentId: _documentController.text,
        photoPath: _capturedPhotoPath,
        embedding: jsonEncode(_generatedEmbedding),
      );

      // Guardar en la base de datos con manejo seguro
      final personId = await _dbService.insertPerson(person);

      // Registrar evento de análisis exitoso
      await _identificationService.registerAnalysisEvent(
        imagePath: _capturedPhotoPath!,
        analysisType: 'registration_completed',
        wasSuccessful: true,
        personId: personId,
        documentId: _documentController.text,
        personName: _nameController.text,
        confidence: 1.0,
        processingTimeMs: DateTime.now().millisecondsSinceEpoch - 
                        DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
        metadata: {
          'person_id': personId.toString(),
          'embedding_dimensions': _generatedEmbedding!.length,
          'photo_path': _capturedPhotoPath!,
        },
      );

      // Mostrar éxito y resetear formulario
      setState(() {
        _currentStep = EnrollmentStep.success;
        _statusMessage = 'Registro completado exitosamente (ID: $personId)';
        _isProcessing = false;
      });

      // Auto-reset después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _resetForm();
        }
      });
    } catch (e) {
      // Registrar evento de error
      await _identificationService.registerAnalysisEvent(
        imagePath: _capturedPhotoPath ?? 'unknown',
        analysisType: 'registration_failed',
        wasSuccessful: false,
        documentId: _documentController.text,
        personName: _nameController.text,
        confidence: 0.0,
        processingTimeMs: 0,
        metadata: {
          'error': e.toString(),
          'step': 'database_insert',
        },
      );
      
      _showError('Error de registro', 'No se pudo completar el registro: $e');
    }
  }

  /// Resetea el formulario para un nuevo registro
  void _resetForm() {
    setState(() {
      _currentStep = EnrollmentStep.personalData;
      _nameController.clear();
      _documentController.clear();
      _capturedPhotoPath = null;
      _generatedEmbedding = null;
      _statusMessage = '';
      _isProcessing = false;
    });
  }

  /// Muestra error con SnackBar
  void _showError(String title, String message) {
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Error: $message';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Persona'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Nuevo registro',
          ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de progreso
          _buildProgressIndicator(),

          // Contenido principal
          Expanded(
            child: _buildStepContent(),
          ),

          // Barra de estado
          _buildStatusBar(),
        ],
      ),
    );
  }

  /// Construye el indicador de progreso visual
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          _buildStepIndicator(1, 'Datos', EnrollmentStep.personalData),
          _buildStepLine(_currentStep.index > 0),
          _buildStepIndicator(2, 'Foto', EnrollmentStep.photoCapture),
          _buildStepLine(_currentStep.index > 1),
          _buildStepIndicator(3, 'Procesamiento', EnrollmentStep.embeddingGeneration),
          _buildStepLine(_currentStep.index > 2),
          _buildStepIndicator(4, 'Confirmar', EnrollmentStep.confirmation),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, String label, EnrollmentStep step) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep.index > step.index;

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isCompleted
                ? Colors.green
                : isActive
                    ? Colors.deepPurple
                    : Colors.grey[300],
            child: Icon(
              isCompleted
                  ? Icons.check
                  : isActive
                      ? Icons.circle
                      : Icons.circle_outlined,
              size: 16,
              color: (isActive || isCompleted) ? Colors.white : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: (isActive || isCompleted) ? Colors.deepPurple : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? Colors.green : Colors.grey[300],
        margin: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  /// Construye el contenido según el paso actual
  Widget _buildStepContent() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando...'),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case EnrollmentStep.personalData:
        return _buildPersonalDataForm();
      case EnrollmentStep.photoCapture:
        return _buildPhotoCaptureStep();
      case EnrollmentStep.embeddingGeneration:
        return _buildEmbeddingGenerationStep();
      case EnrollmentStep.confirmation:
        return _buildConfirmationStep();
      case EnrollmentStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildPersonalDataForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Datos Personales',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo *',
                hintText: 'Ingrese el nombre completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                final validation = ValidationUtils.validatePersonName(value);
                return validation.isValid ? null : validation.error;
              },
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _documentController,
              decoration: const InputDecoration(
                labelText: 'Número de Documento *',
                hintText: 'Ingrese el documento de identidad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: (value) {
                final validation = ValidationUtils.validateDocumentId(value);
                return validation.isValid ? null : validation.error;
              },
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _processPersonalData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCaptureStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Captura Biométrica',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt, size: 64, color: Colors.deepPurple),
                  const SizedBox(height: 16),
                  Text(
                    'Persona: ${_nameController.text}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Documento: ${_documentController.text}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Capture una foto clara del rostro para generar la identificación biométrica.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          ElevatedButton.icon(
            onPressed: _capturePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capturar Foto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () => setState(() => _currentStep = EnrollmentStep.personalData),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddingGenerationStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Procesamiento Biométrico',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          if (_capturedPhotoPath != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_capturedPhotoPath!),
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Generando características biométricas únicas...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),

          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando imagen...'),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirmar Registro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_capturedPhotoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_capturedPhotoPath!),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text('Documento: ${_documentController.text}'),
                            if (_generatedEmbedding != null)
                              Text('Características: ${_generatedEmbedding!.length}D'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Los datos biométricos se han procesado correctamente. ¿Confirma el registro de esta persona?',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          ElevatedButton.icon(
            onPressed: _completeRegistration,
            icon: const Icon(Icons.save),
            label: const Text('Confirmar y Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () => setState(() => _currentStep = EnrollmentStep.photoCapture),
            child: const Text('Capturar Nueva Foto'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 100,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Registro Exitoso!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Persona: ${_nameController.text}',
            style: const TextStyle(fontSize: 18),
          ),
          Text(
            'Documento: ${_documentController.text}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'La persona ha sido registrada exitosamente en el sistema biométrico.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.person_add),
            label: const Text('Registrar Nueva Persona'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Row(
        children: [
          Icon(
            _statusMessage.startsWith('Error')
                ? Icons.error
                : Icons.info,
            color: _statusMessage.startsWith('Error')
                ? Colors.red
                : Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage.isEmpty ? 'Complete los datos para continuar' : _statusMessage,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    super.dispose();
  }
}

/// Enumeración de los pasos del proceso de registro
enum EnrollmentStep {
  personalData,
  photoCapture,
  embeddingGeneration,
  confirmation,
  success,
}
