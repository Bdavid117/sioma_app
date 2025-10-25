# Guía de Riverpod en SIOMA App

## 📋 Tabla de Contenidos
- [Introducción](#introducción)
- [Arquitectura](#arquitectura)
- [Providers Disponibles](#providers-disponibles)
- [Cómo Usar Riverpod](#cómo-usar-riverpod)
- [Ejemplos Prácticos](#ejemplos-prácticos)
- [Mejores Prácticas](#mejores-prácticas)

## Introducción

Riverpod es un sistema de gestión de estado reactivo para Flutter que nos permite:
- **Separar lógica de negocio de la UI**
- **Gestión de estado predecible y testeable**
- **Inyección de dependencias automática**
- **Reactividad automática** (cuando cambia el estado, la UI se actualiza)

## Arquitectura

```
lib/
├── providers/
│   ├── service_providers.dart    # Providers para servicios (singleton)
│   └── state_providers.dart      # Providers para estado de UI
├── services/                     # Lógica de negocio pura
├── screens/                      # UI que consume providers
└── models/                       # Modelos de datos
```

### Flujo de Datos

```
User Action → Screen (ConsumerWidget)
              ↓
         ref.read(provider)
              ↓
         Service Logic
              ↓
         StateNotifier.state = newState
              ↓
         ref.watch(provider) → UI Auto-Update
```

## Providers Disponibles

### Service Providers (`service_providers.dart`)

#### 1. `databaseServiceProvider`
```dart
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
```
- **Tipo**: `Provider<DatabaseService>`
- **Uso**: Acceso a la base de datos SQLite
- **Ciclo de vida**: Singleton (se crea una vez)

#### 2. `faceEmbeddingServiceProvider`
```dart
final faceEmbeddingServiceProvider = Provider<FaceEmbeddingService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return FaceEmbeddingService(databaseService: databaseService);
});
```
- **Tipo**: `Provider<FaceEmbeddingService>`
- **Uso**: Generación de embeddings faciales
- **Dependencias**: `databaseServiceProvider`

#### 3. `identificationServiceProvider`
```dart
final identificationServiceProvider = Provider<IdentificationService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final embeddingService = ref.watch(faceEmbeddingServiceProvider);
  return IdentificationService(
    databaseService: databaseService,
    embeddingService: embeddingService,
  );
});
```
- **Tipo**: `Provider<IdentificationService>`
- **Uso**: Identificación biométrica 1:N
- **Dependencias**: `databaseServiceProvider`, `faceEmbeddingServiceProvider`

#### 4. `cameraServiceProvider`
```dart
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});
```
- **Tipo**: `Provider<CameraService>`
- **Uso**: Gestión de cámara del dispositivo

#### 5. `databaseInitializationProvider`
```dart
final databaseInitializationProvider = FutureProvider<void>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  await databaseService.initDatabase();
});
```
- **Tipo**: `FutureProvider<void>`
- **Uso**: Esperar inicialización de base de datos
- **Patrón**: Loading/Success/Error automático

#### 6. `embeddingInitializationProvider`
```dart
final embeddingInitializationProvider = FutureProvider<void>((ref) async {
  final embeddingService = ref.watch(faceEmbeddingServiceProvider);
  await embeddingService.initialize();
});
```
- **Tipo**: `FutureProvider<void>`
- **Uso**: Esperar carga del modelo TFLite

### State Providers (`state_providers.dart`)

#### 1. `personsProvider`
```dart
final personsProvider = StateNotifierProvider<PersonsNotifier, PersonsState>((ref) {
  return PersonsNotifier();
});
```
- **Tipo**: `StateNotifierProvider<PersonsNotifier, PersonsState>`
- **Estado**: Lista de personas con estados loading/error
- **Métodos**:
  - `setLoading(bool)` - Activar/desactivar loading
  - `setPersons(List<Person>)` - Establecer lista de personas
  - `addPerson(Person)` - Agregar persona
  - `updatePerson(Person)` - Actualizar persona
  - `removePerson(int)` - Eliminar persona
  - `setError(String)` - Establecer error

#### 2. `eventsProvider`
```dart
final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  return EventsNotifier();
});
```
- **Tipo**: `StateNotifierProvider<EventsNotifier, EventsState>`
- **Estado**: Lista de eventos de identificación
- **Métodos**:
  - `setLoading(bool)`
  - `setEvents(List<IdentificationEvent>)`
  - `addEvent(IdentificationEvent)`
  - `clearEvents()`
  - `setError(String)`

#### 3. `identificationProcessProvider`
```dart
final identificationProcessProvider = 
    StateNotifierProvider<IdentificationProcessNotifier, IdentificationProcessState>((ref) {
  return IdentificationProcessNotifier();
});
```
- **Tipo**: `StateNotifierProvider<IdentificationProcessNotifier, IdentificationProcessState>`
- **Estado**: Proceso de identificación en tiempo real
- **Propiedades**:
  - `isProcessing` - Si está procesando
  - `isScanning` - Si está escaneando
  - `currentPersonName` - Persona identificada
  - `confidence` - Nivel de confianza
  - `statusMessage` - Mensaje de estado
  - `errorMessage` - Mensaje de error
- **Métodos**:
  - `startScanning()`
  - `stopScanning()`
  - `startProcessing()`
  - `setIdentificationResult({name, confidence})`
  - `setNoMatch()`
  - `setError(String)`
  - `reset()`

## Cómo Usar Riverpod

### 1. Convertir Widget a Consumer

**Antes (StatefulWidget):**
```dart
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final DatabaseService _dbService = DatabaseService();
  // ...
}
```

**Después (ConsumerStatefulWidget):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  // No más instancias manuales
  // ...
}
```

### 2. Leer Servicios

**Con `ref.read()` (para acciones puntuales):**
```dart
Future<void> _loadData() async {
  final dbService = ref.read(databaseServiceProvider);
  final persons = await dbService.getAllPersons();
  // ...
}
```

**Con `ref.watch()` (para escuchar cambios):**
```dart
@override
Widget build(BuildContext context) {
  // Se reconstruye automáticamente cuando cambia el estado
  final personsState = ref.watch(personsProvider);
  
  if (personsState.isLoading) {
    return CircularProgressIndicator();
  }
  
  final persons = personsState.data ?? [];
  return ListView.builder(/* ... */);
}
```

### 3. Actualizar Estado

```dart
Future<void> _addPerson(Person person) async {
  // 1. Obtener notifier
  final personsNotifier = ref.read(personsProvider.notifier);
  final dbService = ref.read(databaseServiceProvider);
  
  // 2. Activar loading
  personsNotifier.setLoading(true);
  
  try {
    // 3. Operación
    await dbService.insertPerson(person);
    
    // 4. Actualizar estado
    personsNotifier.addPerson(person);
  } catch (e) {
    // 5. Manejar error
    personsNotifier.setError('Error al agregar: $e');
  }
}
```

## Ejemplos Prácticos

### Ejemplo 1: Cargar Lista de Personas

```dart
class PersonsListScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<PersonsListScreen> createState() => _PersonsListScreenState();
}

class _PersonsListScreenState extends ConsumerState<PersonsListScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar datos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersons();
    });
  }
  
  Future<void> _loadPersons() async {
    final personsNotifier = ref.read(personsProvider.notifier);
    final dbService = ref.read(databaseServiceProvider);
    
    personsNotifier.setLoading(true);
    
    try {
      final persons = await dbService.getAllPersons();
      personsNotifier.setPersons(persons);
    } catch (e) {
      personsNotifier.setError('Error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final personsState = ref.watch(personsProvider);
    
    // Loading state
    if (personsState.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    // Error state
    if (personsState.hasError) {
      return Center(
        child: Column(
          children: [
            Text('Error: ${personsState.error}'),
            ElevatedButton(
              onPressed: _loadPersons,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    
    // Data state
    final persons = personsState.data ?? [];
    return ListView.builder(
      itemCount: persons.length,
      itemBuilder: (context, index) {
        final person = persons[index];
        return ListTile(title: Text(person.name));
      },
    );
  }
}
```

### Ejemplo 2: Proceso de Identificación

```dart
class IdentificationScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends ConsumerState<IdentificationScreen> {
  Future<void> _startIdentification(String imagePath) async {
    final processNotifier = ref.read(identificationProcessProvider.notifier);
    final identificationService = ref.read(identificationServiceProvider);
    
    // Iniciar proceso
    processNotifier.startProcessing();
    
    try {
      final result = await identificationService.identifyPerson(imagePath);
      
      if (result.isIdentified) {
        processNotifier.setIdentificationResult(
          personName: result.person!.name,
          confidence: result.confidence!,
        );
      } else {
        processNotifier.setNoMatch();
      }
    } catch (e) {
      processNotifier.setError('Error: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final processState = ref.watch(identificationProcessProvider);
    
    return Column(
      children: [
        if (processState.isProcessing)
          CircularProgressIndicator(),
        
        if (processState.hasIdentification)
          Text('Identificado: ${processState.currentPersonName}'),
        
        if (processState.hasError)
          Text('Error: ${processState.errorMessage}'),
        
        ElevatedButton(
          onPressed: () => _captureAndIdentify(),
          child: Text('Identificar'),
        ),
      ],
    );
  }
}
```

### Ejemplo 3: Esperar Inicialización

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Esperar inicialización de base de datos
    final dbInit = ref.watch(databaseInitializationProvider);
    
    return dbInit.when(
      data: (_) => MainApp(), // ✅ Inicializado
      loading: () => LoadingScreen(), // ⏳ Cargando
      error: (err, stack) => ErrorScreen(error: err), // ❌ Error
    );
  }
}
```

## Mejores Prácticas

### ✅ DO

1. **Usar `ref.read()` para acciones**
```dart
onPressed: () {
  final service = ref.read(databaseServiceProvider);
  service.doSomething();
}
```

2. **Usar `ref.watch()` en build**
```dart
@override
Widget build(BuildContext context) {
  final state = ref.watch(personsProvider);
  return Text('${state.data?.length ?? 0} personas');
}
```

3. **Separar estado de lógica**
```dart
// ✅ Service con lógica pura
class DatabaseService {
  Future<List<Person>> getAllPersons() async { /* ... */ }
}

// ✅ Notifier para estado de UI
class PersonsNotifier extends StateNotifier<PersonsState> {
  void setLoading(bool isLoading) { /* ... */ }
}
```

4. **Manejar estados (loading/error/data)**
```dart
if (state.isLoading) return CircularProgressIndicator();
if (state.hasError) return ErrorWidget(state.error);
return DataWidget(state.data);
```

### ❌ DON'T

1. **No usar `ref.watch()` fuera de build**
```dart
// ❌ MAL
void _loadData() {
  final state = ref.watch(personsProvider); // Error!
}

// ✅ BIEN
void _loadData() {
  final notifier = ref.read(personsProvider.notifier);
}
```

2. **No crear instancias manuales**
```dart
// ❌ MAL
class _MyScreenState extends ConsumerState<MyScreen> {
  final DatabaseService _db = DatabaseService();
}

// ✅ BIEN
class _MyScreenState extends ConsumerState<MyScreen> {
  // Usar ref.read(databaseServiceProvider)
}
```

3. **No olvidar mounted check en async**
```dart
// ✅ BIEN
Future<void> _save() async {
  await service.save();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(/* ... */);
  }
}
```

## Ventajas de Riverpod en SIOMA

1. **Testeable**: Los providers se pueden mockear fácilmente
2. **Sin BuildContext**: No necesitas context para acceder a servicios
3. **Type-safe**: Errores de tipo en compile-time
4. **Autodispose**: Libera recursos automáticamente
5. **DevTools**: Inspección de estado en tiempo real
6. **Hot Reload**: Mantiene el estado durante desarrollo

## Próximos Pasos

- [ ] Migrar todas las pantallas a `ConsumerWidget`
- [ ] Crear providers para cámara en tiempo real
- [ ] Implementar caché de embeddings
- [ ] Agregar persistencia de estado
- [ ] Tests unitarios de providers

## Recursos

- [Documentación oficial Riverpod](https://riverpod.dev)
- [Riverpod vs Provider](https://riverpod.dev/docs/from_provider/motivation)
- [Ejemplos en GitHub](https://github.com/rrousselGit/riverpod/tree/master/examples)
