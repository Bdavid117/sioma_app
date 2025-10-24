import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/person.dart';
import 'dart:convert';

/// Pantalla de prueba para validar la funcionalidad de la base de datos
class DatabaseTestScreen extends StatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  State<DatabaseTestScreen> createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends State<DatabaseTestScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();

  List<Person> _persons = [];
  int _personsCount = 0;
  int _eventsCount = 0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final persons = await _dbService.getAllPersons();
      final personsCount = await _dbService.getPersonsCount();
      final eventsCount = await _dbService.getEventsCount();

      setState(() {
        _persons = persons;
        _personsCount = personsCount;
        _eventsCount = eventsCount;
        _statusMessage = 'Datos cargados exitosamente';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al cargar: $e';
      });
    }
  }

  Future<void> _addTestPerson() async {
    if (_nameController.text.isEmpty || _documentController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Por favor ingrese nombre y documento';
      });
      return;
    }

    try {
      // Crear embedding de prueba (simulando un vector de 128 dimensiones)
      final fakeEmbedding = List.generate(128, (i) => i * 0.01);

      final person = Person(
        name: _nameController.text,
        documentId: _documentController.text,
        embedding: jsonEncode(fakeEmbedding),
      );

      await _dbService.insertPerson(person);

      _nameController.clear();
      _documentController.clear();

      setState(() {
        _statusMessage = 'Persona agregada exitosamente';
      });

      await _loadData();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al agregar: $e';
      });
    }
  }

  Future<void> _deletePerson(int id) async {
    try {
      await _dbService.deletePerson(id);
      setState(() {
        _statusMessage = 'Persona eliminada';
      });
      await _loadData();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al eliminar: $e';
      });
    }
  }

  Future<void> _clearDatabase() async {
    try {
      await _dbService.deleteDatabase();
      setState(() {
        _statusMessage = 'Base de datos eliminada';
        _persons = [];
        _personsCount = 0;
        _eventsCount = 0;
      });
      await _loadData();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al eliminar BD: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Base de Datos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar'),
                  content: const Text('¿Eliminar toda la base de datos?'),
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
              if (confirm == true) _clearDatabase();
            },
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
                Text(
                  'Estado: $_statusMessage',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCard(
                      label: 'Personas',
                      value: _personsCount.toString(),
                      icon: Icons.people,
                    ),
                    _StatCard(
                      label: 'Eventos',
                      value: _eventsCount.toString(),
                      icon: Icons.event,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Formulario de entrada
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _documentController,
                      decoration: const InputDecoration(
                        labelText: 'Documento',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addTestPerson,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Persona de Prueba'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Lista de personas
          Expanded(
            child: _persons.isEmpty
                ? const Center(
                    child: Text('No hay personas registradas'),
                  )
                : ListView.builder(
                    itemCount: _persons.length,
                    itemBuilder: (context, index) {
                      final person = _persons[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(person.name[0].toUpperCase()),
                          ),
                          title: Text(person.name),
                          subtitle: Text('Doc: ${person.documentId}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deletePerson(person.id!),
                          ),
                        ),
                      );
                    },
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.deepPurple),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

