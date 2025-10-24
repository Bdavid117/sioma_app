import 'package:flutter/material.dart';
import '../services/face_embedding_service.dart';
import '../services/camera_service.dart';
import '../screens/camera_capture_screen.dart';
import 'dart:io';
import 'dart:convert';

/// Pantalla de prueba para validar la funcionalidad de embeddings faciales
class EmbeddingTestScreen extends StatefulWidget {
  const EmbeddingTestScreen({super.key});

  @override
  State<EmbeddingTestScreen> createState() => _EmbeddingTestScreenState();
}

class _EmbeddingTestScreenState extends State<EmbeddingTestScreen> {
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final CameraService _cameraService = CameraService();

  List<File> _testImages = [];
  Map<String, List<double>> _imageEmbeddings = {};
  String _statusMessage = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Inicializando servicios...';
    });

    try {
      final embeddingSuccess = await _embeddingService.initialize();

      setState(() {
        _isInitialized = embeddingSuccess;
        _statusMessage = embeddingSuccess
            ? 'Servicios inicializados correctamente'
            : 'Error al inicializar servicios';
        _isLoading = false;
      });

      if (_isInitialized) {
        await _loadTestImages();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTestImages() async {
    setState(() {
      _statusMessage = 'Cargando imágenes de prueba...';
    });

    try {
      final photos = await _cameraService.getSavedPhotos();
      setState(() {
        _testImages = photos;
        _statusMessage = 'Imágenes cargadas: ${photos.length}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al cargar imágenes: $e';
      });
    }
  }

  Future<void> _generateEmbedding(File imageFile) async {
    final fileName = imageFile.path.split('/').last;

    setState(() {
      _statusMessage = 'Generando embedding para $fileName...';
    });

    try {
      final embedding = await _embeddingService.generateEmbedding(imageFile.path);

      if (embedding != null) {
        setState(() {
          _imageEmbeddings[imageFile.path] = embedding;
          _statusMessage = 'Embedding generado para $fileName (${embedding.length}D)';
        });
      } else {
        setState(() {
          _statusMessage = 'Error: No se pudo generar embedding para $fileName';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al generar embedding: $e';
      });
    }
  }

  Future<void> _generateAllEmbeddings() async {
    if (_testImages.isEmpty) {
      setState(() {
        _statusMessage = 'No hay imágenes para procesar';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Generando embeddings para todas las imágenes...';
    });

    try {
      for (int i = 0; i < _testImages.length; i++) {
        final imageFile = _testImages[i];
        final fileName = imageFile.path.split('/').last;

        setState(() {
          _statusMessage = 'Procesando ${i + 1}/${_testImages.length}: $fileName';
        });

        final embedding = await _embeddingService.generateEmbedding(imageFile.path);

        if (embedding != null) {
          _imageEmbeddings[imageFile.path] = embedding;
        }

        // Pequeña pausa para mostrar el progreso
        await Future.delayed(const Duration(milliseconds: 500));
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Embeddings generados: ${_imageEmbeddings.length}/${_testImages.length}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al generar embeddings: $e';
      });
    }
  }

  void _compareEmbeddings() {
    if (_imageEmbeddings.length < 2) {
      setState(() {
        _statusMessage = 'Se necesitan al menos 2 embeddings para comparar';
      });
      return;
    }

    final embeddings = _imageEmbeddings.entries.toList();
    final results = <String>[];

    for (int i = 0; i < embeddings.length; i++) {
      for (int j = i + 1; j < embeddings.length; j++) {
        final path1 = embeddings[i].key;
        final path2 = embeddings[j].key;
        final emb1 = embeddings[i].value;
        final emb2 = embeddings[j].value;

        final similarity = _embeddingService.calculateSimilarity(emb1, emb2);

        final fileName1 = path1.split('/').last;
        final fileName2 = path2.split('/').last;

        results.add('$fileName1 ↔ $fileName2: ${(similarity * 100).toStringAsFixed(1)}%');
      }
    }

    _showComparisonResults(results);
  }

  void _showComparisonResults(List<String> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comparación de Embeddings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Similitudes calculadas:'),
              const SizedBox(height: 16),
              ...results.map((result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showEmbeddingDetails(String imagePath, List<double> embedding) {
    final fileName = imagePath.split('/').last;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Embedding: $fileName'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dimensiones: ${embedding.length}'),
              Text('Rango: [${embedding.reduce((a, b) => a < b ? a : b).toStringAsFixed(4)}, ${embedding.reduce((a, b) => a > b ? a : b).toStringAsFixed(4)}]'),
              const SizedBox(height: 16),
              const Text('Primeros 10 valores:'),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    embedding.take(10).map((v) => v.toStringAsFixed(6)).join('\n'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copiar embedding completo (útil para debug)
              final jsonString = _embeddingService.embeddingToJson(embedding);
              setState(() {
                _statusMessage = 'Embedding copiado (${jsonString.length} caracteres)';
              });
              Navigator.pop(context);
            },
            child: const Text('Copiar JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureNewImage() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraCaptureScreen(
          personName: 'Test Embedding',
          documentId: 'TEST001',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _statusMessage = 'Nueva imagen capturada';
      });
      await _loadTestImages();
    }
  }

  Widget _buildModelInfo() {
    final info = _embeddingService.getModelInfo();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del Modelo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tamaño de entrada: ${info['inputSize']}x${info['inputSize']}'),
            Text('Dimensiones de embedding: ${info['embeddingSize']}'),
            Text('Estado: ${info['isInitialized'] ? 'Inicializado' : 'No inicializado'}'),
            Text('Modo: ${info['mode']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_testImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay imágenes de prueba',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Captura fotos para generar embeddings',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: _testImages.length,
      itemBuilder: (context, index) {
        final imageFile = _testImages[index];
        final fileName = imageFile.path.split('/').last;
        final hasEmbedding = _imageEmbeddings.containsKey(imageFile.path);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                    if (hasEmbedding)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (hasEmbedding)
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 20),
                            onPressed: () => _showEmbeddingDetails(
                              imageFile.path,
                              _imageEmbeddings[imageFile.path]!,
                            ),
                            tooltip: 'Ver detalles',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.psychology, size: 20),
                            onPressed: () => _generateEmbedding(imageFile),
                            tooltip: 'Generar embedding',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Embeddings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTestImages,
            tooltip: 'Recargar imágenes',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'generate_all':
                  _generateAllEmbeddings();
                  break;
                case 'compare':
                  _compareEmbeddings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'generate_all',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 8),
                    Text('Generar Todos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'compare',
                child: Row(
                  children: [
                    Icon(Icons.compare),
                    SizedBox(width: 8),
                    Text('Comparar Embeddings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Estado y estadísticas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isInitialized ? Icons.check_circle : Icons.error,
                      color: _isInitialized ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage.isEmpty ? 'Listo para generar embeddings' : _statusMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      label: 'Imágenes',
                      value: '${_testImages.length}',
                      icon: Icons.photo_library,
                    ),
                    _StatChip(
                      label: 'Embeddings',
                      value: '${_imageEmbeddings.length}',
                      icon: Icons.psychology,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Información del modelo
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildModelInfo(),
          ),

          // Grid de imágenes
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Procesando embeddings...'),
                      ],
                    ),
                  )
                : _buildImageGrid(),
          ),
        ],
      ),

      // Botón flotante para capturar nueva imagen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _captureNewImage,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Capturar Imagen'),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.deepPurple),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}
