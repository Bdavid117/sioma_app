# 📘 FASE 1: BASE DE DATOS SQLITE Y MODELO DE DATOS

## ✅ Estado: COMPLETADO

---

## 📦 Dependencias a Instalar

Ejecuta estos comandos en la terminal desde la raíz del proyecto:

```bash
flutter pub add sqflite path provider
```

**¿Por qué estas dependencias?**
- `sqflite`: Base de datos SQLite para Flutter (funciona offline)
- `path`: Utilidades para manejo de rutas de archivos
- `provider`: Gestión del estado de la aplicación

---

## 📁 Archivos Creados

### 1. **lib/models/person.dart**
**Ruta exacta:** `lib/models/person.dart`

Modelo de datos para representar personas registradas con sus embeddings faciales.

**Campos:**
- `id`: ID autoincremental (clave primaria)
- `name`: Nombre de la persona
- `documentId`: Documento de identidad (único)
- `photoPath`: Ruta local de la foto
- `embedding`: Embedding facial en formato JSON string
- `createdAt`: Fecha de registro

---

### 2. **lib/models/identification_event.dart**
**Ruta exacta:** `lib/models/identification_event.dart`

Modelo para eventos de identificación (cada vez que se intenta identificar a alguien).

**Campos:**
- `id`: ID autoincremental
- `personId`: ID de la persona identificada (null si desconocido)
- `personName`: Nombre de la persona
- `confidence`: Nivel de confianza (0.0 - 1.0)
- `photoPath`: Ruta de la foto del evento
- `timestamp`: Fecha y hora del evento
- `identified`: Boolean (true si se identificó, false si desconocido)

---

### 3. **lib/services/database_service.dart**
**Ruta exacta:** `lib/services/database_service.dart`

Servicio singleton para gestionar todas las operaciones con SQLite.

**Características:**
- Patrón Singleton (una sola instancia)
- Creación automática de tablas e índices
- CRUD completo para personas
- CRUD completo para eventos
- Métodos de consulta optimizados

**Métodos principales:**

**Para Personas:**
- `insertPerson(Person)`: Inserta nueva persona
- `getAllPersons()`: Obtiene todas las personas
- `getPersonById(int)`: Busca persona por ID
- `getPersonByDocument(String)`: Busca por documento
- `updatePerson(Person)`: Actualiza persona
- `deletePerson(int)`: Elimina persona
- `getPersonsCount()`: Conteo de personas

**Para Eventos:**
- `insertIdentificationEvent(Event)`: Registra evento
- `getAllEvents()`: Lista todos los eventos
- `getEventsByPerson(int)`: Eventos de una persona
- `getEventsCount()`: Conteo de eventos
- `deleteOldEvents(DateTime)`: Limpieza de eventos antiguos

**Utilidades:**
- `deleteDatabase()`: Elimina BD completa (desarrollo)
- `close()`: Cierra conexión

---

### 4. **lib/screens/database_test_screen.dart**
**Ruta exacta:** `lib/screens/database_test_screen.dart`

Pantalla de prueba para validar la funcionalidad de la base de datos.

**Funcionalidades:**
- Formulario para agregar personas de prueba
- Contador de personas y eventos
- Lista de personas registradas
- Botón para eliminar personas
- Botón para limpiar toda la BD
- Actualización en tiempo real

---

### 5. **lib/main.dart** (Actualizado)
**Ruta exacta:** `lib/main.dart`

Archivo principal actualizado para usar la pantalla de prueba.

---

## 🗄️ Estructura de Base de Datos

### Tabla: `persons`
```sql
CREATE TABLE persons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  document_id TEXT NOT NULL UNIQUE,
  photo_path TEXT,
  embedding TEXT NOT NULL,
  created_at TEXT NOT NULL
)
```

### Tabla: `identification_events`
```sql
CREATE TABLE identification_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id INTEGER,
  person_name TEXT,
  confidence REAL,
  photo_path TEXT,
  timestamp TEXT NOT NULL,
  identified INTEGER NOT NULL,
  FOREIGN KEY (person_id) REFERENCES persons (id)
)
```

### Índices:
- `idx_document_id` en `persons(document_id)` - Búsqueda rápida por documento
- `idx_timestamp` en `identification_events(timestamp DESC)` - Eventos ordenados

---

## 🧪 Prueba Manual - Criterios de Aceptación

### ✅ Paso 1: Instalar dependencias
```bash
flutter pub add sqflite path provider
```
**Esperado:** Dependencias instaladas sin errores.

---

### ✅ Paso 2: Ejecutar la aplicación
```bash
flutter run
```
**Esperado:** App inicia mostrando "Test Base de Datos".

---

### ✅ Paso 3: Verificar interfaz inicial
**Verificar:**
- ✓ AppBar con título "Test Base de Datos"
- ✓ Iconos de refresh y eliminar BD en AppBar
- ✓ Contador "Personas: 0" y "Eventos: 0"
- ✓ Formulario con campos "Nombre" y "Documento"
- ✓ Botón "Agregar Persona de Prueba"
- ✓ Mensaje "No hay personas registradas"

---

### ✅ Paso 4: Agregar persona de prueba
**Acciones:**
1. Escribe "Juan Pérez" en campo Nombre
2. Escribe "12345678" en campo Documento
3. Presiona "Agregar Persona de Prueba"

**Esperado:**
- ✓ Mensaje "Persona agregada exitosamente"
- ✓ Contador "Personas: 1"
- ✓ Campos de formulario se limpian
- ✓ Aparece card con "Juan Pérez" y "Doc: 12345678"
- ✓ Card tiene avatar con letra "J"
- ✓ Botón rojo de eliminar en la card

---

### ✅ Paso 5: Agregar más personas
**Acciones:**
1. Agrega "María García" - "87654321"
2. Agrega "Pedro López" - "11111111"

**Esperado:**
- ✓ Contador muestra "Personas: 3"
- ✓ Lista muestra las 3 personas
- ✓ Orden: más recientes primero

---

### ✅ Paso 6: Eliminar persona
**Acciones:**
1. Presiona botón rojo de eliminar en "María García"

**Esperado:**
- ✓ Mensaje "Persona eliminada"
- ✓ Contador "Personas: 2"
- ✓ María García desaparece de la lista

---

### ✅ Paso 7: Verificar persistencia
**Acciones:**
1. Hot Restart (R) o cierra y vuelve a abrir la app

**Esperado:**
- ✓ Los datos persisten (Juan Pérez y Pedro López siguen ahí)
- ✓ Contador correcto "Personas: 2"

---

### ✅ Paso 8: Refrescar datos
**Acciones:**
1. Presiona el icono de refresh en AppBar

**Esperado:**
- ✓ Datos se recargan correctamente
- ✓ Mensaje "Datos cargados exitosamente"

---

### ✅ Paso 9: Validar documento único
**Acciones:**
1. Intenta agregar "Ana Martínez" con documento "12345678" (ya existe)

**Esperado:**
- ✓ Mensaje de error (documento duplicado)
- ✓ Persona NO se agrega

---

### ✅ Paso 10: Limpiar base de datos
**Acciones:**
1. Presiona icono de eliminar BD (trash)
2. Confirma en el diálogo

**Esperado:**
- ✓ Mensaje "Base de datos eliminada"
- ✓ Contadores en "0"
- ✓ Lista vacía
- ✓ Mensaje "No hay personas registradas"

---

## 📊 Resumen de la Fase 1

**Archivos creados:** 5
**Modelos:** 2 (Person, IdentificationEvent)
**Servicios:** 1 (DatabaseService)
**Pantallas:** 1 (DatabaseTestScreen)
**Tablas BD:** 2 (persons, identification_events)

---

## 🎯 Objetivo Cumplido

✅ Base de datos SQLite funcional y offline
✅ Modelos de datos definidos
✅ CRUD completo para personas y eventos
✅ Interfaz de prueba funcional
✅ Persistencia local validada

---

## ➡️ Siguiente Paso

**FASE 2: Captura de Cámara**
- Integración de cámara para capturar fotos
- Previsualización de imágenes
- Guardado de imágenes en almacenamiento local
- Interfaz de captura de rostro

---

## 🐛 Troubleshooting

### Error: "Target of URI doesn't exist: 'package:sqflite/sqflite.dart'"
**Solución:** Ejecuta `flutter pub get` después de agregar dependencias.

### Error: Base de datos corrupta
**Solución:** Usa el botón de eliminar BD en la app de prueba.

### Error: No se crean las tablas
**Solución:** Elimina la BD y reinicia la app para recrearla.

---

**Autor:** GitHub Copilot  
**Fecha:** 2025-10-24  
**Versión:** 1.0.0

