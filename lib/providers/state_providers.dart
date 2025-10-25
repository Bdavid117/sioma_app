import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person.dart';
import '../models/identification_event.dart';

/// Estado genérico para operaciones asíncronas
class AsyncState<T> {
  final bool isLoading;
  final T? data;
  final String? error;

  const AsyncState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  AsyncState<T> copyWith({
    bool? isLoading,
    T? data,
    String? error,
  }) {
    return AsyncState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }

  bool get hasError => error != null;
  bool get hasData => data != null;
}

/// Estado para la lista de personas registradas
class PersonsState extends AsyncState<List<Person>> {
  const PersonsState({
    super.isLoading,
    super.data,
    super.error,
  });

  @override
  PersonsState copyWith({
    bool? isLoading,
    List<Person>? data,
    String? error,
  }) {
    return PersonsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

/// Notifier para gestionar el estado de personas
class PersonsNotifier extends StateNotifier<PersonsState> {
  PersonsNotifier() : super(const PersonsState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setPersons(List<Person> persons) {
    state = state.copyWith(
      isLoading: false,
      data: persons,
      error: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      isLoading: false,
      error: error,
    );
  }

  void addPerson(Person person) {
    final currentPersons = state.data ?? [];
    state = state.copyWith(
      data: [...currentPersons, person],
    );
  }

  void updatePerson(Person person) {
    final currentPersons = state.data ?? [];
    final updatedPersons = currentPersons.map((p) {
      return p.id == person.id ? person : p;
    }).toList();
    state = state.copyWith(data: updatedPersons);
  }

  void removePerson(int personId) {
    final currentPersons = state.data ?? [];
    final updatedPersons = currentPersons.where((p) => p.id != personId).toList();
    state = state.copyWith(data: updatedPersons);
  }
}

/// Provider para el estado de personas
final personsProvider = StateNotifierProvider<PersonsNotifier, PersonsState>((ref) {
  return PersonsNotifier();
});

/// Estado para la lista de eventos de identificación
class EventsState extends AsyncState<List<IdentificationEvent>> {
  const EventsState({
    super.isLoading,
    super.data,
    super.error,
  });

  @override
  EventsState copyWith({
    bool? isLoading,
    List<IdentificationEvent>? data,
    String? error,
  }) {
    return EventsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

/// Notifier para gestionar el estado de eventos
class EventsNotifier extends StateNotifier<EventsState> {
  EventsNotifier() : super(const EventsState());

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setEvents(List<IdentificationEvent> events) {
    state = state.copyWith(
      isLoading: false,
      data: events,
      error: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      isLoading: false,
      error: error,
    );
  }

  void addEvent(IdentificationEvent event) {
    final currentEvents = state.data ?? [];
    state = state.copyWith(
      data: [event, ...currentEvents], // Nuevos eventos al inicio
    );
  }

  void clearEvents() {
    state = state.copyWith(data: []);
  }
}

/// Provider para el estado de eventos
final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  return EventsNotifier();
});

/// Estado para el proceso de identificación en tiempo real
class IdentificationProcessState {
  final bool isProcessing;
  final bool isScanning;
  final String? currentPersonName;
  final double? confidence;
  final String? statusMessage;
  final String? errorMessage;

  const IdentificationProcessState({
    this.isProcessing = false,
    this.isScanning = false,
    this.currentPersonName,
    this.confidence,
    this.statusMessage,
    this.errorMessage,
  });

  IdentificationProcessState copyWith({
    bool? isProcessing,
    bool? isScanning,
    String? currentPersonName,
    double? confidence,
    String? statusMessage,
    String? errorMessage,
  }) {
    return IdentificationProcessState(
      isProcessing: isProcessing ?? this.isProcessing,
      isScanning: isScanning ?? this.isScanning,
      currentPersonName: currentPersonName ?? this.currentPersonName,
      confidence: confidence ?? this.confidence,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get hasIdentification => currentPersonName != null;
}

/// Notifier para el proceso de identificación
class IdentificationProcessNotifier extends StateNotifier<IdentificationProcessState> {
  IdentificationProcessNotifier() : super(const IdentificationProcessState());

  void startScanning() {
    state = state.copyWith(
      isScanning: true,
      statusMessage: 'Escaneando rostros...',
      errorMessage: null,
    );
  }

  void stopScanning() {
    state = state.copyWith(
      isScanning: false,
      isProcessing: false,
    );
  }

  void startProcessing() {
    state = state.copyWith(
      isProcessing: true,
      statusMessage: 'Procesando identificación...',
    );
  }

  void setIdentificationResult({
    required String personName,
    required double confidence,
  }) {
    state = state.copyWith(
      isProcessing: false,
      currentPersonName: personName,
      confidence: confidence,
      statusMessage: 'Identificado: $personName (${(confidence * 100).toStringAsFixed(1)}%)',
      errorMessage: null,
    );
  }

  void setNoMatch() {
    state = state.copyWith(
      isProcessing: false,
      currentPersonName: null,
      confidence: null,
      statusMessage: 'No se encontró coincidencia',
      errorMessage: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      isProcessing: false,
      isScanning: false,
      errorMessage: error,
      statusMessage: null,
    );
  }

  void reset() {
    state = const IdentificationProcessState();
  }
}

/// Provider para el estado del proceso de identificación
final identificationProcessProvider = 
    StateNotifierProvider<IdentificationProcessNotifier, IdentificationProcessState>((ref) {
  return IdentificationProcessNotifier();
});
