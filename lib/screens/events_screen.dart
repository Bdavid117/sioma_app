import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/analysis_event.dart';
import '../models/identification_event.dart';
import '../models/custom_event.dart';
import '../models/person.dart';
import '../providers/service_providers.dart';
import '../providers/state_providers.dart';
import 'dart:convert';

/// Pantalla de gestión de eventos de registro
/// Permite ver historial completo de identificaciones y análisis
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  List<AnalysisEvent> _analysisEvents = [];
  List<IdentificationEvent> _identificationEvents = [];
  String _selectedFilter = 'all'; // 'all', 'successful', 'failed', 'registration', 'identification'
  
  // Estadísticas
  int _totalEvents = 0;
  int _successfulEvents = 0;
  int _todayEvents = 0;
  
  @override
  void initState() {
    super.initState();
    // Cargar eventos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    final eventsNotifier = ref.read(eventsProvider.notifier);
    final dbService = ref.read(databaseServiceProvider);
    
    eventsNotifier.setLoading(true);

    try {
      // Cargar eventos de análisis (más detallados)
      _analysisEvents = await dbService.getAllAnalysisEvents();
      
      // Cargar eventos de identificación tradicionales
      final identEvents = await dbService.getAllEvents(limit: 1000);
      
      setState(() {
        _identificationEvents = identEvents;
      });
      
      // Actualizar estado en Riverpod
      eventsNotifier.setEvents(identEvents);
      
      // Calcular estadísticas
      _calculateStats();
    } catch (e) {
      eventsNotifier.setError('Error al cargar eventos: $e');
      if (mounted) {
        _showError('Error al cargar eventos: $e');
      }
    }
  }

  void _calculateStats() {
    _totalEvents = _analysisEvents.length + _identificationEvents.length;
    _successfulEvents = _analysisEvents.where((e) => e.wasSuccessful).length +
                       _identificationEvents.where((e) => e.identified).length;
    
    final today = DateTime.now();
    _todayEvents = _analysisEvents.where((e) => 
      e.timestamp.year == today.year &&
      e.timestamp.month == today.month &&
      e.timestamp.day == today.day
    ).length + _identificationEvents.where((e) =>
      e.timestamp.year == today.year &&
      e.timestamp.month == today.month &&
      e.timestamp.day == today.day
    ).length;
  }

  List<Widget> _getFilteredEvents() {
    List<Widget> events = [];
    
    // Agregar eventos de análisis
    for (var event in _analysisEvents) {
      if (_shouldShowEvent(event)) {
        events.add(_buildAnalysisEventTile(event));
      }
    }
    
    // Agregar eventos de identificación tradicionales
    for (var event in _identificationEvents) {
      if (_shouldShowIdentificationEvent(event)) {
        events.add(_buildIdentificationEventTile(event));
      }
    }
    
    // Ordenar por fecha descendente
    events.sort((a, b) {
      final aKey = a.key as ValueKey<DateTime>;
      final bKey = b.key as ValueKey<DateTime>;
      return bKey.value.compareTo(aKey.value);
    });
    
    return events;
  }

  bool _shouldShowEvent(AnalysisEvent event) {
    switch (_selectedFilter) {
      case 'successful':
        return event.wasSuccessful;
      case 'failed':
        return !event.wasSuccessful;
      case 'registration':
        return event.analysisType.contains('registration');
      case 'identification':
        return event.analysisType.contains('identification');
      default:
        return true;
    }
  }

  bool _shouldShowIdentificationEvent(IdentificationEvent event) {
    switch (_selectedFilter) {
      case 'successful':
        return event.identified;
      case 'failed':
        return !event.identified;
      case 'registration':
        return false; // Los eventos de identificación no son de registro
      case 'identification':
        return true;
      default:
        return true;
    }
  }

  Widget _buildAnalysisEventTile(AnalysisEvent event) {
    final isSuccessful = event.wasSuccessful;
    final icon = _getEventIcon(event.analysisType, isSuccessful);
    final color = isSuccessful ? Colors.green : Colors.red;
    
    return Card(
      key: ValueKey(event.timestamp),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          event.identifiedPersonName ?? 'Persona no identificada',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSuccessful ? Colors.green[700] : Colors.red[700],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatEventType(event.analysisType)),
            Text(
              '${_formatDateTime(event.timestamp)} • ${event.processingTimeMs}ms',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (event.confidence != null)
              Text(
                'Confianza: ${(event.confidence! * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: isSuccessful 
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.error, color: Colors.red),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  Widget _buildIdentificationEventTile(IdentificationEvent event) {
    final isSuccessful = event.identified;
    final color = isSuccessful ? Colors.blue : Colors.orange;
    
    return Card(
      key: ValueKey(event.timestamp),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isSuccessful ? Icons.person_search : Icons.person_search_outlined,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          event.personName ?? 'Desconocido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSuccessful ? Colors.blue[700] : Colors.orange[700],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identificación tradicional'),
            Text(
              _formatDateTime(event.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (event.confidence != null)
              Text(
                'Confianza: ${(event.confidence! * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: isSuccessful 
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : const Icon(Icons.help_outline, color: Colors.orange),
      ),
    );
  }

  IconData _getEventIcon(String eventType, bool isSuccessful) {
    if (eventType.contains('registration')) {
      return isSuccessful ? Icons.person_add : Icons.person_add_disabled;
    } else if (eventType.contains('identification')) {
      return isSuccessful ? Icons.person_search : Icons.search_off;
    } else if (eventType.contains('embedding')) {
      return isSuccessful ? Icons.psychology : Icons.psychology_outlined;
    }
    return isSuccessful ? Icons.check : Icons.error;
  }

  String _formatEventType(String eventType) {
    switch (eventType) {
      case 'registration_completed':
        return 'Registro completado';
      case 'registration_failed':
        return 'Registro fallido';
      case 'identification':
        return 'Identificación exitosa';
      case 'identification_failed':
        return 'Identificación fallida';
      case 'embedding_generated':
        return 'Embedding generado';
      case 'embedding_failed':
        return 'Error en embedding';
      default:
        return eventType.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showEventDetails(AnalysisEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles del Evento'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Tipo', _formatEventType(event.analysisType)),
              _buildDetailRow('Persona', event.identifiedPersonName ?? 'N/A'),
              _buildDetailRow('Estado', event.wasSuccessful ? 'Exitoso' : 'Fallido'),
              _buildDetailRow('Fecha', event.timestamp.toString()),
              _buildDetailRow('Tiempo procesamiento', '${event.processingTimeMs}ms'),
              if (event.confidence != null)
                _buildDetailRow('Confianza', '${(event.confidence! * 100).toStringAsFixed(2)}%'),
              if (event.imagePath != null)
                _buildDetailRow('Imagen', event.imagePath!),
              _buildDetailRow('Dispositivo', event.deviceInfo),
              _buildDetailRow('Versión App', event.appVersion),
              
              if (event.metadata.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(event.metadata),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
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

  Widget _buildDetailRow(String label, String value) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showManualEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const ManualEventRegistrationDialog(),
    ).then((result) {
      if (result == true) {
        _loadEvents(); // Recargar eventos si se registró uno nuevo
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Observar el estado de eventos desde Riverpod
    final eventsState = ref.watch(eventsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Eventos'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEventDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar Evento'),
      ),
      body: eventsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : eventsState.hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(eventsState.error ?? 'Error desconocido'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadEvents,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Estadísticas
                    _buildStatsSection(),
                    
                    // Filtros
                    _buildFilterSection(),
                    
                    // Lista de eventos
                    Expanded(
                      child: _buildEventsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              _totalEvents.toString(),
              Icons.event,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Exitosos',
              _successfulEvents.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Hoy',
              _todayEvents.toString(),
              Icons.today,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Todos', 'all'),
            _buildFilterChip('Exitosos', 'successful'),
            _buildFilterChip('Fallidos', 'failed'),
            _buildFilterChip('Registros', 'registration'),
            _buildFilterChip('Identificaciones', 'identification'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.deepPurple.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildEventsList() {
    final filteredEvents = _getFilteredEvents();
    
    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay eventos que mostrar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) => filteredEvents[index],
    );
  }
}

/// Diálogo para registro manual de eventos de entrada/salida
class ManualEventRegistrationDialog extends StatefulWidget {
  const ManualEventRegistrationDialog({super.key});

  @override
  State<ManualEventRegistrationDialog> createState() => _ManualEventRegistrationDialogState();
}

class _ManualEventRegistrationDialogState extends State<ManualEventRegistrationDialog> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _documentController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  List<Person> _persons = [];
  Person? _selectedPerson;
  String _selectedEventType = 'entrada';
  String _selectedLocation = 'finca_principal';
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _persons = await _dbService.getAllPersons();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al cargar personas: $e');
    }
  }

  Future<void> _searchPersonByDocument() async {
    if (_documentController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final person = await _dbService.getPersonByDocument(_documentController.text.trim());
      setState(() {
        _selectedPerson = person;
        _isSearching = false;
      });

      if (person == null) {
        _showError('No se encontró ninguna persona con ese documento');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showError('Error al buscar persona: $e');
    }
  }

  Future<void> _registerEvent() async {
    if (_selectedPerson == null) {
      _showError('Debe seleccionar una persona');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final CustomEvent event;
      
      if (_selectedEventType == 'entrada') {
        event = CustomEvent.entrada(
          personId: _selectedPerson!.id!,
          personName: _selectedPerson!.name,
          personDocument: _selectedPerson!.documentId,
          location: _selectedLocation,
          notes: _notesController.text.trim(),
        );
      } else {
        event = CustomEvent.salida(
          personId: _selectedPerson!.id!,
          personName: _selectedPerson!.name,
          personDocument: _selectedPerson!.documentId,
          location: _selectedLocation,
          notes: _notesController.text.trim(),
        );
      }

      await _dbService.insertCustomEvent(event);

      if (mounted) {
        Navigator.of(context).pop(true); // Retorna true para indicar que se registró un evento
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_selectedEventType.toUpperCase()} registrada para ${_selectedPerson!.name}'),
            backgroundColor: _selectedEventType == 'entrada' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al registrar evento: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Evento Manual'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Búsqueda por documento
            const Text('Buscar Persona:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _documentController,
                    decoration: const InputDecoration(
                      hintText: 'Número de documento',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedPerson = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSearching ? null : _searchPersonByDocument,
                  icon: _isSearching 
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Dropdown de personas (alternativo)
            const Text('O seleccionar de la lista:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Person>(
              value: _selectedPerson,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              hint: const Text('Seleccionar persona'),
              items: _persons.map((person) => DropdownMenuItem(
                value: person,
                child: Text('${person.name} (${person.documentId})'),
              )).toList(),
              onChanged: (person) {
                setState(() {
                  _selectedPerson = person;
                  if (person != null) {
                    _documentController.text = person.documentId;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Tipo de evento
            const Text('Tipo de Evento:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Entrada'),
                    value: 'entrada',
                    groupValue: _selectedEventType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEventType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Salida'),
                    value: 'salida',
                    groupValue: _selectedEventType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEventType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ubicación
            const Text('Ubicación:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: CustomEvent.predefinedLocations.entries.map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value['name'] as String),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Notas opcionales
            const Text('Notas (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Agregar observaciones...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedPerson == null ? null : _registerEvent,
          child: _isLoading 
              ? const CircularProgressIndicator()
              : const Text('Registrar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _documentController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}