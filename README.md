# SIOMA App — Reconocimiento Facial on‑device (Flutter)

SIOMA es una app móvil de reconocimiento facial completamente on‑device (sin internet) construida con Flutter. Permite registrar personas y realizar identificación automática en tiempo real desde la cámara del dispositivo, guardando eventos de entrada/salida con metadatos en una base de datos SQLite local.

- Precisión mejorada con validación de rostro mediante Google ML Kit (detección de rostro y chequeos de calidad)
- Embeddings deterministas de 256 dimensiones normalizados (L2)
- Umbral adaptativo y métrica de similitud combinada para robustez en condiciones reales
- Registro de eventos con foto, nombre del evento, fecha/hora y confianza
- Base de datos local con migraciones y verificación de esquema al inicio


## Diferenciales

- 100% on‑device: no envía imágenes ni datos biométricos a la nube.
- Robustez: validaciones de calidad de rostro + umbrales adaptativos mejoran la tasa de aciertos en escenarios reales.
- Determinismo: embeddings 256D normalizados con parsing sólido de versiones legadas.
- Estabilidad: migraciones de base de datos (hasta v6) y verificación automática de columnas requeridas.
- Operación continua: modo AUTO con escaneo periódico y gestión de ciclo de vida para evitar fugas y bloqueos.


## Arquitectura (capas y flujo)

Componentes principales:

- UI (Flutter): pantallas para registro e identificación (manual/auto) y pruebas.
- Servicios:
  - Cámara: captura frames para validación/identificación.
  - ML Kit (Face Detection): valida presencia y calidad del rostro (posición, tamaño, ojos abiertos, etc., según configuración).
  - Embeddings: genera y normaliza vectores 256D; utilidades de serialización JSON.
  - Identificación: calcula similitud (métrica combinada) y aplica umbrales adaptativos.
  - Base de datos: CRUD de personas y eventos; migraciones y verificación de esquema.
- Modelos: Person, IdentificationEvent/CustomEvent.

Diagrama ASCII de alto nivel:

```
┌───────────────┐      Frames        ┌──────────────────────┐
│   Cámara      │ ─────────────────▶ │  Validación (ML Kit) │
└──────┬────────┘                   └──────────┬───────────┘
       │  Rostro OK                                │
       ▼                                           ▼
┌──────────────────────┐                  ┌──────────────────────┐
│ Embeddings 256D (L2) │                  │  Servicio Identidad  │
│  - generar/normalizar│                  │  - similitud mixta   │
└──────────┬───────────┘                  │  - umbral adaptativo │
           │                              └──────────┬───────────┘
           ▼                                           │ match/no-match
┌───────────────────────────┐                         ▼
│ Base de datos (SQLite)    │ ◀──────── Guardar ───────────┐
│ - personas                │            eventos           │
│ - eventos (entrada/salida)│                              │
└───────────────────────────┘                              │
                       ▲                                  │
                       └────────────── UI ────────────────┘
```

Rutas clave (referenciales):

- `lib/screens/`: UI de cámara, identificación, pruebas y navegación.
- `lib/services/`:
  - `database_service.dart`: migraciones (hasta v6), verificación de columnas (event_name, photo_path, confidence), límites seguros de consulta.
  - `face_embedding_service.dart`: generación y normalización 256D, (de)serialización JSON, búsqueda por similitud.
  - `enhanced_identification_service.dart`: integración ML Kit, métrica combinada y umbral adaptativo.
- `lib/models/`: `person.dart`, `identification_event.dart` (CustomEvent), entre otros.


## Tecnologías

- Flutter y Dart (UI multiplataforma)
- Cámara (plugin camera) y permisos (permission_handler)
- Google ML Kit Face Detection (validación de rostro on‑device)
- SQLite (sqflite) + path_provider
- Android, iOS, Web, Desktop (soporte Flutter; foco principal en Android)

Probado con Flutter 3.35.x y Dart 3.9.x.


## Instalación y requisitos

1) Requisitos
- Flutter SDK instalado y configurado
- Android Studio (SDK/Emulador/ADB) y Java 17+ (según versión de Flutter)
- En macOS, Xcode para iOS (opcional)

2) Dependencias
- Ejecuta la instalación de paquetes de Dart/Flutter (al abrir el proyecto, o desde tu IDE). Si prefieres CLI: `flutter pub get`.

3) Permisos
- Android requiere permisos de cámara y almacenamiento (configurados en el proyecto). La app solicita/gestiona permisos en tiempo de ejecución.


## Uso básico

1) Registrar persona
- Abre la pantalla “Registrar Persona”.
- Captura una foto del rostro con buena iluminación y encuadre.
- La app validará el rostro con ML Kit; si es adecuado, generará el embedding 256D y guardará la persona en la base local.

2) Identificación manual
- En “Identificación”, toma una foto. La app valida el rostro y calcula similitud contra la base local, mostrando coincidencia (si supera el umbral adaptativo) y la confianza.

3) Modo AUTO (reconocimiento en línea)
- Activa el modo AUTO para escaneo periódico desde la cámara.
- Ante un match, registra un evento (entrada/salida) con foto, confianza y timestamp.


## Pipeline de reconocimiento (detalle)

1. Captura de frame desde cámara.
2. Detección de rostro con ML Kit y validaciones de calidad (tamaño/posición/estabilidad, etc.).
3. Generación de embedding 256D y normalización L2.
4. Cálculo de similitud con métrica combinada (por ejemplo, cosine + ajustes heurísticos).
5. Umbral adaptativo (más estricto para rostros dudosos; más permisivo con alta calidad).
6. Decisión: match/no‑match; si match, registrar evento (entrada/salida) con metadatos.


## Datos y modelo

Tablas principales (SQLite):

- persons
  - id, name, document, embedding_json (vector 256D serializado), created_at, updated_at
- custom_events (v6)
  - id, person_id, event_name (texto), photo_path (opcional), confidence (real), created_at

La app verifica al inicio que existan las columnas críticas (event_name, photo_path, confidence) y las agrega si faltan (auto‑healing ligero del esquema).


## Métricas y umbrales

- Similaridad: combinación de métricas (p. ej., coseno) sobre embeddings normalizados.
- Umbral: adaptativo según calidad del rostro detectado por ML Kit.
- Embeddings: 256D deterministas y L2‑normalizados para resultados estables.

Puedes ajustar valores o lógica en `lib/services/enhanced_identification_service.dart` y utilidades de embeddings en `lib/services/face_embedding_service.dart`.


## Compilación y APK

Para generar un APK de lanzamiento (release) en Android:

```
flutter clean
flutter pub get
flutter build apk --release
```

El APK resultante se ubicará en `build/app/outputs/flutter-apk/app-release.apk`.

Firmado: para distribuir públicamente, configura una keystore y firma el APK/Bundle según la guía oficial de Flutter/Android. En entornos internos, puedes usar la firma de depuración para pruebas.


## Pruebas

La base incluye pruebas unitarias y de widgets. Para ejecutarlas:

```
flutter test -r compact
```

Nota: si usas SQLite FFI en tests, la ejecución está serializada para evitar bloqueos de base de datos.


## Seguridad y privacidad

- Procesamiento local: las imágenes y embeddings no salen del dispositivo.
- Permisos mínimos: cámara y almacenamiento local.
- Recomendaciones: proteger el dispositivo con bloqueo (PIN/biometría). Si se almacenan fotos, hacerlo en rutas privadas de la app.
- Sin cifrado a nivel de app por defecto; si tu caso de uso lo requiere, añade cifrado de archivos/DB.


## Solución de problemas

- “No detecta rostro”: verifica iluminación, distancia y encuadre; limpia la lente; reintenta.
- “Falsos positivos/negativos”: agrega más muestras por persona, revisa umbrales y validaciones en el servicio de identificación.
- “database is locked” en tests o desarrollo: evita instancias paralelas de la DB; cierra la app previa; ejecuta pruebas en serie.
- Errores de ciclo de vida (cámara/auto): asegúrate de que el modo AUTO se detiene al salir de la pantalla; la app ya lo gestiona con guards.


## Roadmap (sugerencias)

- Liveness/anti‑spoofing (parpadeo, profundidad, reflejos)
- Multi‑rostro y seguimiento simultáneo
- Ajuste fino de umbrales por persona o contexto
- Exportación/backup de base local y sincronización opcional (on‑prem/cloud)
- Panel de auditoría y métricas (TP/FP/FN, tiempos, calidad)
- Mejora de UX/UI y accesibilidad


## Equipo y soporte

- Owner/Maintainer: @Bdavid117
- Issues y soporte: usa el sistema de incidencias del repositorio o contacta al mantenedor.


## Licencia

Este repositorio no define explícitamente una licencia pública. Salvo indicación en contrario, considera el uso interno y solicita autorización al propietario antes de redistribuir. Si se añade un archivo `LICENSE`, ese documento prevalecerá.
