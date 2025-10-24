import 'package:flutter/material.dart';
import '../services/camera_service.dart';
import '../screens/camera_capture_screen.dart';
import 'dart:io';

/// Pantalla de prueba para validar la funcionalidad de la cámara
class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  final CameraService _cameraService = CameraService();
  List<File> _savedPhotos = [];
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhotos();
  }

  Future<void> _loadSavedPhotos() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando fotos guardadas...';
    });

    try {
      final photos = await _cameraService.getSavedPhotos();
      setState(() {
        _savedPhotos = photos;
        _statusMessage = 'Fotos cargadas: ${photos.length}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al cargar fotos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraCaptureScreen(
          personName: 'Persona de Prueba',
          documentId: '12345678',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _statusMessage = 'Foto capturada: ${result.split('/').last}';
      });
      await _loadSavedPhotos();
    }
  }

  Future<void> _deletePhoto(File photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Foto'),
        content: Text('¿Eliminar ${photo.path.split('/').last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _cameraService.deletePhoto(photo.path);
      setState(() {
        _statusMessage = success
            ? 'Foto eliminada'
            : 'Error al eliminar foto';
      });
      await _loadSavedPhotos();
    }
  }

  void _showPhotoDetails(File photo) {
    final fileName = photo.path.split('/').last;
    final fileStat = photo.statSync();
    final fileSize = (fileStat.size / 1024).round(); // KB

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                photo,
                width: 250,
                height: 250,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text('Tamaño: ${fileSize} KB'),
            Text('Modificado: ${fileStat.modified.toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(photo);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllPhotos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Todas las Fotos'),
        content: Text('¿Eliminar las ${_savedPhotos.length} fotos guardadas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Todas', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      int deleted = 0;
      for (final photo in _savedPhotos) {
        if (await _cameraService.deletePhoto(photo.path)) {
          deleted++;
        }
      }

      setState(() {
        _statusMessage = '$deleted fotos eliminadas';
      });
      await _loadSavedPhotos();
    }
  }

  Widget _buildPhotoGrid() {
    if (_savedPhotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay fotos guardadas',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Usa el botón de cámara para capturar fotos',
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
        childAspectRatio: 1,
      ),
      itemCount: _savedPhotos.length,
      itemBuilder: (context, index) {
        final photo = _savedPhotos[index];
        final fileName = photo.path.split('/').last;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showPhotoDetails(photo),
            child: Column(
              children: [
                Expanded(
                  child: Image.file(
                    photo,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Cámara'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedPhotos,
            tooltip: 'Recargar fotos',
          ),
          if (_savedPhotos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllPhotos,
              tooltip: 'Eliminar todas',
            ),
        ],
      ),
      body: Column(
        children: [
          // Estado y estadísticas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage.isEmpty ? 'Listo para capturar fotos' : _statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_savedPhotos.length} fotos',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Grid de fotos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPhotoGrid(),
          ),
        ],
      ),

      // Botón flotante para abrir cámara
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capturar Foto'),
      ),
    );
  }
}
