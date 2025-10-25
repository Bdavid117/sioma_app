import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import '../providers/service_providers.dart';
import '../providers/state_providers.dart';
import 'dart:io';

/// Pantalla para gestionar las personas registradas en el sistema
class RegisteredPersonsScreen extends ConsumerStatefulWidget {
  const RegisteredPersonsScreen({super.key});

  @override
  ConsumerState<RegisteredPersonsScreen> createState() => _RegisteredPersonsScreenState();
}

class _RegisteredPersonsScreenState extends ConsumerState<RegisteredPersonsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Person> _filteredPersons = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // Cargar personas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersons();
    });
  }

  Future<void> _loadPersons() async {
    // Usar el notifier de Riverpod
    final personsNotifier = ref.read(personsProvider.notifier);
    final dbService = ref.read(databaseServiceProvider);
    
    personsNotifier.setLoading(true);

    try {
      final persons = await dbService.getAllPersons(limit: 100);
      final count = await dbService.getPersonsCount();

      personsNotifier.setPersons(persons);
      setState(() {
        _filteredPersons = persons;
        _totalCount = count;
      });
    } catch (e) {
      personsNotifier.setError('Error al cargar personas: $e');
    }
  }

  void _filterPersons(String query) {
    final allPersons = ref.read(personsProvider).data ?? [];
    
    setState(() {
      if (query.isEmpty) {
        _filteredPersons = allPersons;
      } else {
        _filteredPersons = allPersons.where((person) {
          final searchLower = query.toLowerCase();
          return person.name.toLowerCase().contains(searchLower) ||
                 person.documentId.toLowerCase().contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _deletePerson(Person person) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Persona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Está seguro de eliminar a esta persona?'),
            const SizedBox(height: 16),
            Text('Nombre: ${person.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Documento: ${person.documentId}'),
            const SizedBox(height: 16),
            const Text('Esta acción no se puede deshacer.',
                 style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final dbService = ref.read(databaseServiceProvider);
        final personsNotifier = ref.read(personsProvider.notifier);
        
        await dbService.deletePerson(person.id!);

        // Eliminar foto asociada si existe
        if (person.photoPath != null && await File(person.photoPath!).exists()) {
          await File(person.photoPath!).delete();
        }

        // Actualizar estado en Riverpod
        personsNotifier.removePerson(person.id!);
        
        // Actualizar lista filtrada local
        setState(() {
          _filteredPersons.removeWhere((p) => p.id == person.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${person.name} ha sido eliminado del sistema'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showPersonDetails(Person person) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(person.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (person.photoPath != null && File(person.photoPath!).existsSync())
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(person.photoPath!),
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _DetailRow(label: 'ID', value: person.id.toString()),
              _DetailRow(label: 'Documento', value: person.documentId),
              _DetailRow(label: 'Registrado', value: _formatDate(person.createdAt)),
              if (person.photoPath != null)
                _DetailRow(label: 'Foto', value: person.photoPath!.split('/').last),
              _DetailRow(label: 'Características', value: '${person.embedding.length} caracteres'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePerson(person);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Buscar persona',
          hintText: 'Nombre o documento...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterPersons('');
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: _filterPersons,
      ),
    );
  }

  Widget _buildPersonsList() {
    // Obtener estado de Riverpod
    final personsState = ref.watch(personsProvider);
    
    if (personsState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando personas...'),
          ],
        ),
      );
    }

    if (personsState.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(personsState.error ?? 'Error desconocido'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPersons,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_filteredPersons.isEmpty) {
      final allPersons = personsState.data ?? [];
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              allPersons.isEmpty ? Icons.people_outline : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              allPersons.isEmpty
                  ? 'No hay personas registradas'
                  : 'No se encontraron resultados',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (allPersons.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Usa la pestaña "Registro" para agregar personas',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredPersons.length,
      itemBuilder: (context, index) {
        final person = _filteredPersons[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: _buildPersonAvatar(person),
            title: Text(
              person.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doc: ${person.documentId}'),
                Text(
                  'Registrado: ${_formatDate(person.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    _showPersonDetails(person);
                    break;
                  case 'delete':
                    _deletePerson(person);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Ver detalles'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showPersonDetails(person),
          ),
        );
      },
    );
  }

  Widget _buildPersonAvatar(Person person) {
    if (person.photoPath != null && File(person.photoPath!).existsSync()) {
      return CircleAvatar(
        backgroundImage: FileImage(File(person.photoPath!)),
      );
    } else {
      return CircleAvatar(
        backgroundColor: Colors.deepPurple,
        child: Text(
          person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  Widget _buildStatusBar() {
    final personsState = ref.watch(personsProvider);
    final allPersonsCount = personsState.data?.length ?? 0;
    
    String statusMessage = 'Total: $_totalCount personas | Mostrando: ${_filteredPersons.length}';
    
    if (personsState.hasError) {
      statusMessage = personsState.error!;
    } else if (personsState.isLoading) {
      statusMessage = 'Cargando personas registradas...';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(
            personsState.hasError ? Icons.error_outline : Icons.info_outline,
            color: personsState.hasError ? Colors.red : Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusMessage,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas Registradas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPersons,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildPersonsList()),
          _buildStatusBar(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
