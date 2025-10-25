# 🎭 SIOMA - Sistema Inteligente de Organización y Monitoreo Avanzado# 🔬 SIOMA - Sistema de Identificación Offline con Machine Learning y Análisis



<div align="center">[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)

[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)

![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)

![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)

![License](https://img.shields.io/badge/License-MIT-green)## 📋 Descripción

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)

SIOMA es una **aplicación Flutter 100% offline** para reconocimiento facial y gestión biométrica local. Implementa captura de cámara, generación de embeddings faciales determinísticos, identificación 1:N y persistencia local con SQLite. Diseñada para entornos donde la privacidad y el funcionamiento sin conexión son críticos.

**Sistema de reconocimiento facial y gestión de eventos con captura inteligente de imágenes**

## ✨ Características Principales

[Características](#-características) •

[Instalación](#-instalación) •- 🔐 **100% Offline** - No requiere conexión a internet, datos nunca salen del dispositivo

[Uso](#-uso) •- 📸 **Captura Biométrica** - Cámara con guías visuales y validación de calidad

[Arquitectura](#-arquitectura) •- 🧠 **IA Local** - Generación determinística de embeddings faciales (512D)

[Contribuir](#-contribuir)- 🔍 **Identificación 1:N** - Búsqueda contra base de datos local con múltiples métricas

- 🗄️ **Persistencia SQLite** - Almacenamiento local seguro y validado

</div>- 🛡️ **Seguridad** - Validaciones robustas, manejo seguro de datos, sin telemetría

- 📱 **Multiplataforma** - Android, iOS, Windows, macOS, Linux

---- 📊 **Auditoría Completa** - Registro detallado de eventos de identificación

- ⚡ **Alto Rendimiento** - Identificación en < 5 segundos contra 1000+ personas

## 📋 Descripción

## 🚀 Instalación Rápida

SIOMA es una aplicación móvil avanzada de reconocimiento facial que utiliza inteligencia artificial para identificar personas y registrar eventos de entrada/salida. Cuenta con un sistema de **captura inteligente automática** que analiza la calidad de las fotos en tiempo real para garantizar el máximo nivel de precisión en el reconocimiento.

```bash

### 🎯 Problema que Resuelve# Clonar el repositorio

git clone <repository-url>

- Control de acceso biométrico en tiempo realcd sioma_app

- Registro automático de eventos (entradas/salidas)

- Identificación rápida y precisa de personas# Instalar dependencias

- Captura optimizada de fotos para máxima precisiónflutter pub get



## ✨ Características# Ejecutar la aplicación

flutter run

### 🤖 Captura Inteligente Automática

# Compilar para producción

- **Análisis de calidad en tiempo real**: Evalúa iluminación, nitidez y contrasteflutter build apk --release  # Android

- **Captura automática**: Toma la foto cuando detecta condiciones óptimasflutter build ios --release  # iOS

- **Feedback visual**: Indicadores de calidad en pantallaflutter build windows --release  # Windows

- **Modo manual opcional**: Control total del usuario cuando lo necesite```



### 🔍 Reconocimiento Facial Avanzado## 📂 Estructura del Proyecto



- Identificación 1:N contra base de datos completa```

- Algoritmo de similitud coseno optimizadosioma_app/

- Umbrales adaptativos basados en histórico├── lib/

- Score de confianza detallado│   ├── main.dart                 # Punto de entrada

│   ├── models/                   # Modelos de datos

### 📊 Gestión de Eventos│   │   ├── person.dart           # Modelo de persona con embedding

│   │   ├── identification_event.dart

- Registro automático de entradas/salidas│   │   └── analysis_event.dart

- Historial completo con timestamps│   ├── screens/                  # Pantallas UI

- Búsqueda y filtrado eficiente│   │   ├── main_navigation_screen.dart

- Estadísticas de uso│   │   ├── person_enrollment_screen.dart

│   │   ├── identification_screen.dart

### 🗃️ Base de Datos Optimizada│   │   ├── advanced_identification_screen.dart

│   │   └── registered_persons_screen.dart

- SQLite con 6 índices optimizados│   ├── services/                 # Lógica de negocio

- Consultas paginadas eficientes│   │   ├── database_service.dart

- Búsqueda full-text en personas│   │   ├── camera_service.dart

- Migración automática de esquemas│   │   ├── face_embedding_service.dart

│   │   └── identification_service.dart

### 📝 Sistema de Logging Profesional│   ├── utils/                    # Utilidades

│   │   └── validation_utils.dart

- 4 niveles de logging (debug, info, warning, error)│   └── tools/                    # Herramientas de diagnóstico

- Loggers especializados (Camera, Database, Identification)│       └── biometric_diagnostic.dart

- Trazabilidad completa de operaciones├── docs/                         # Documentación técnica

│   ├── FASE_1_BASE_DATOS.md

## 🚀 Instalación│   ├── FASE_2_CAMARA.md

│   ├── FASE_3_EMBEDDINGS.md

### Prerrequisitos│   ├── FASE_4_REGISTRO.md

│   ├── FASE_5_IDENTIFICACION.md

```bash│   ├── SEGURIDAD.md

Flutter SDK: >=3.9.2│   └── TESTING.md

Dart SDK: >=3.0.0├── tools/                        # Scripts de validación

Android Studio / Xcode (para desarrollo móvil)│   ├── test_fixes.dart

```│   ├── validate_fixes.dart

│   └── validate_capture_fixes.dart

### Pasos de Instalación├── test/                         # Tests unitarios

└── assets/                       # Recursos estáticos

1. **Clonar el repositorio**```



```bash## 🎯 Funcionalidades Implementadas

git clone https://github.com/Bdavid117/sioma_app.git

cd sioma_app### ✅ FASE 1: Base de Datos SQLite

```- **Modelos de datos:** `Person`, `IdentificationEvent`, `AnalysisEvent`

- **CRUD completo** con validaciones de seguridad

2. **Instalar dependencias**- **Protección contra inyección SQL** y sanitización de inputs

- **Sistema de logging** estructurado sin datos sensibles

```bash

flutter pub get### ✅ FASE 2: Captura de Cámara

```- **Servicio de cámara** con permisos automáticos multiplataforma

- **Interfaz profesional** con guías visuales para posicionamiento

3. **Ejecutar la aplicación**- **Gestión segura** de archivos multimedia con límites de tamaño

- **Limpieza automática** de almacenamiento temporal

```bash

# En dispositivo Android### ✅ FASE 3: Embeddings Faciales

flutter run -d <device_id>- **Generación determinística** - misma imagen = mismo embedding (512D)

- **Hash robusto** basado en píxeles con patrón fijo (stepX/stepY)

# En emulador- **Múltiples métricas:** Similitud coseno (70%), euclidiana (20%), manhattan (10%)

flutter run- **Normalización L2** para consistencia

- **Sin ruido aleatorio** - eliminado para reproducibilidad

# En modo release

flutter run --release### ✅ FASE 4: Registro (Enrollment)

```- **Flujo paso a paso:** Datos → Captura → Procesamiento → Confirmación

- **Validación completa:** Nombres (2-100 chars), documentos únicos

## 📱 Uso- **Integración total:** Cámara + IA + Base de Datos

- **Gestión de personas:** Búsqueda, visualización, eliminación segura

### Registrar una Persona

### ✅ FASE 5: Identificación 1:N

1. Abrir la aplicación- **Algoritmo multi-métrica** con pesos optimizados

2. Ir a la pestaña **"Registrar"**- **Threshold dinámico:** 0.50 por defecto (ajustable según historial)

3. Tocar **"Captura Inteligente"**- **Logging exhaustivo:** Logs con emojis (🔍📊👥✅❌⚠️) para debugging

4. Posicionar el rostro frente a la cámara- **Detección de inconsistencias** entre métricas

5. El sistema capturará automáticamente cuando detecte calidad óptima- **Estadísticas en tiempo real** (tasa de identificación, confianza promedio)

6. Ingresar nombre y documento

7. Guardar## 🏗️ Arquitectura del Sistema



### Identificar una Persona```

┌──────────────────────┐

1. Ir a la pestaña **"Identificar"**│   📱 UI Layer        │  Screens + Widgets

2. Seleccionar modo:├──────────────────────┤

   - **Manual**: Tomar foto y comparar│   🔧 Services Layer  │  Business Logic (Singleton)

   - **Automático**: Scanner en tiempo real│   • CameraService    │

3. El sistema mostrará:│   • EmbeddingService │  ┌─────────────────┐

   - Persona identificada│   • IdentificationSv │──┤ 🧠 Embedding    │

   - Nivel de confianza│   • DatabaseService  │  │ • Deterministic │

   - Opción de registrar evento├──────────────────────┤  │ • 512D vectors  │

│   🗄️ Data Layer      │  │ • Multi-metric  │

### Ver Eventos│   • SQLite DB        │  └─────────────────┘

│   • File Storage     │

1. Ir a la pestaña **"Eventos"**│   • Validations      │

2. Ver historial completo de entradas/salidas└──────────────────────┘

3. Filtrar por fecha, persona o tipo de evento```



## 🏗️ Arquitectura### Flujo de Identificación 1:N



### Stack Tecnológico```

Imagen → Embedding (512D) → Comparación Multi-Métrica → Threshold → Resultado

```   ↓

Frontend:        Flutter + Material Design[Coseno×0.7 + Euclidiana×0.2 + Manhattan×0.1] ≥ 0.50 → ✅ Identificado

Estado:          Riverpod (State Management)```

Base de Datos:   SQLite + sqflite

Cámara:          camera package## 🧪 Pruebas y Diagnóstico

Procesamiento:   image package (análisis de calidad)

Logging:         logger package### Herramienta de Diagnóstico Automático

```

```bash

### Estructura del Proyecto# Ejecutar diagnóstico completo del sistema biométrico

dart run lib/tools/biometric_diagnostic.dart

``````

lib/

├── main.dart                           # Entry point**Verifica:**

├── models/                             # Modelos de datos- ✅ Personas en base de datos

│   ├── person.dart- ✅ Validez de embeddings almacenados (dimensiones, valores)

│   ├── custom_event.dart- ✅ Determinismo (misma imagen → mismo embedding)

│   └── identification_event.dart- ✅ Similitud con BD (detecta problemas de reconocimiento)

├── services/                           # Lógica de negocio- ✅ Simulación de identificación 1:N real

│   ├── database_service.dart           # SQLite

│   ├── camera_service.dart             # Cámara### Tests Manuales

│   ├── identification_service.dart     # Reconocimiento

│   ├── photo_quality_analyzer.dart     # 🆕 Análisis de calidad1. **Registro** → `PersonEnrollmentScreen` - Registra personas completas

│   └── face_embedding_service.dart     # Embeddings2. **Identificación** → `AdvancedIdentificationScreen` - Identifica 1:N

├── providers/                          # Riverpod providers3. **Gestión** → `RegisteredPersonsScreen` - Administra BD

│   ├── service_providers.dart          # Providers de servicios4. **Cámara** → `CameraTestScreen` - Prueba captura

│   └── state_providers.dart            # Notifiers de estado5. **Embeddings** → `EmbeddingTestScreen` - Compara similitudes

├── screens/                            # Pantallas UI

│   ├── smart_camera_capture_screen.dart # 🆕 Captura inteligenteVer [`docs/TESTING.md`](./docs/TESTING.md) para códigos detallados.

│   ├── identification_screen.dart

│   ├── registered_persons_screen.dart## 📖 Documentación Técnica

│   └── events_screen.dart

└── utils/Toda la documentación se encuentra en [`docs/`](./docs/):

    └── app_logger.dart                 # Sistema de logging

```| Documento | Descripción |

|-----------|-------------|

### Patrón de Diseño| [`FASE_1_BASE_DATOS.md`](./docs/FASE_1_BASE_DATOS.md) | SQLite, modelos y validaciones |

| [`FASE_2_CAMARA.md`](./docs/FASE_2_CAMARA.md) | Captura biométrica y multimedia |

**MVVM + Repository Pattern + Dependency Injection**| [`FASE_3_EMBEDDINGS.md`](./docs/FASE_3_EMBEDDINGS.md) | IA, vectores y similitud |

| [`FASE_4_REGISTRO.md`](./docs/FASE_4_REGISTRO.md) | Enrollment paso a paso |

- **Models**: Entidades de datos| [`FASE_5_IDENTIFICACION.md`](./docs/FASE_5_IDENTIFICACION.md) | Sistema 1:N completo |

- **Services**: Lógica de negocio (Repository)| [`SEGURIDAD.md`](./docs/SEGURIDAD.md) | Medidas de seguridad implementadas |

- **Providers**: Inyección de dependencias (DI)| [`TESTING.md`](./docs/TESTING.md) | Guías de pruebas y validación |

- **Screens**: Views + ViewModels (Riverpod State)

## 🛡️ Seguridad y Privacidad

## 🔧 Configuración

### Validaciones Implementadas

### Permisos Necesarios- ✅ **Sanitización de inputs** - Nombres (regex), documentos (alfanuméricos)

- ✅ **Protección SQL injection** - Prepared statements

**Android** (`android/app/src/main/AndroidManifest.xml`):- ✅ **Path traversal** - Validación de rutas de archivos

```xml- ✅ **Límites de recursos** - Imágenes (32x32-4096x4096, 1KB-20MB)

<uses-permission android:name="android.permission.CAMERA" />- ✅ **Embeddings** - Dimensiones 128-1024, valores numéricos válidos

<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />### Privacidad

```- 🔒 **Sin telemetría** - Datos nunca salen del dispositivo

- 🔒 **Sin conexión requerida** - 100% offline

**iOS** (`ios/Runner/Info.plist`):- 🔒 **Logging seguro** - Sin datos biométricos en logs

```xml- 🔒 **SQLite local** - No hay servicios cloud

<key>NSCameraUsageDescription</key>- 🔒 **Preparado para encriptación** - SQLCipher compatible

<string>Se requiere acceso a la cámara para capturar fotos faciales</string>

<key>NSPhotoLibraryUsageDescription</key>## 🔧 Configuración y Ajustes

<string>Se requiere acceso a la galería para guardar fotos</string>

```### Threshold de Identificación



## 📊 Métricas de Calidad```dart

// En identification_service.dart

### Análisis de Foto Automáticothreshold: 0.50  // Valor por defecto



El sistema evalúa 3 métricas clave:// Recomendaciones:

// 0.40-0.50: Embeddings simulados (actual)

1. **Iluminación** (30% peso): Rango óptimo 30-80%// 0.65-0.75: Modelos ML reales (FaceNet, ArcFace)

2. **Nitidez** (50% peso): Detección de bordes Sobel// 0.80-0.90: Máxima seguridad (más falsos negativos)

3. **Contraste** (20% peso): Desviación estándar de luminosidad```



**Score mínimo para captura automática**: 75%### Dimensiones de Embeddings



**Frames consecutivos requeridos**: 3```dart

// En face_embedding_service.dart

## 🧪 TestingembeddingSize = 512  // Actual (simulado)



```bash// Compatibles:

# Tests unitarios// 128D: FaceNet

flutter test// 512D: ArcFace, SphereFace

// 1024D: Custom models

# Tests de integración```

flutter test integration_test/

### Rendimiento

# Análisis de código

flutter analyze```dart

// Límites recomendados

# Formatear códigopersonas_registradas: 1000  // Identificación < 5s

flutter format lib/scan_interval: 600ms  // Tiempo entre capturas automáticas

```min_consecutive_detections: 2  // Anti-falsos positivos

```

## 📦 Build

## 🐛 Solución de Problemas

```bash

# Android APK### ❌ No reconoce personas registradas

flutter build apk --release

1. **Ejecutar diagnóstico:**

# Android App Bundle   ```bash

flutter build appbundle --release   dart run lib/tools/biometric_diagnostic.dart

   ```

# iOS

flutter build ios --release2. **Verificar embeddings determinísticos:**

```   - Mismo rostro debe generar mismo embedding

   - Si difieren, revisar `face_embedding_service.dart`

## 🤝 Contribuir

3. **Ajustar threshold:**

Las contribuciones son bienvenidas! Por favor:   ```dart

   // Reducir si similitudes < 0.65

1. Fork el proyecto   threshold: 0.40

2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)   ```

3. Commit tus cambios (`git commit -m 'Add: AmazingFeature'`)

4. Push a la rama (`git push origin feature/AmazingFeature`)4. **Re-registrar personas** si embeddings corruptos

5. Abre un Pull Request

### ❌ Botón "Registrar" no funciona

### Guía de Estilo

- ✅ **Corregido:** Ahora navega al tab de Registro (índice 0)

- Usar `flutter format` antes de commit- Usa `DefaultTabController.of(context).animateTo(0)`

- Seguir [Effective Dart](https://dart.dev/guides/language/effective-dart)

- Documentar funciones públicas### ⚠️ Similitudes muy bajas

- Escribir tests para nuevas features

- **Causa:** Embeddings no determinísticos o ruido aleatorio

## 📝 Licencia- **Solución:** Verificar ausencia de `Random()` en generación



Este proyecto está bajo la Licencia MIT. Ver archivo `LICENSE` para más detalles.## 📊 Estado del Proyecto



## 👥 Equipo de Desarrollo- ✅ **FASE 1:** Base de datos SQLite - **COMPLETADO**

- ✅ **FASE 2:** Captura de cámara - **COMPLETADO**  

Desarrollado por **Brayan David Collazos** como parte del programa Talento Tech.- ✅ **FASE 3:** Embeddings faciales - **COMPLETADO**

- ✅ **FASE 4:** Registro de personas - **COMPLETADO**

---- ✅ **FASE 5:** Identificación 1:N - **COMPLETADO**

- 🚧 **FASE 6:** Interfaz completa - **EN PROGRESO**

## 🙏 Agradecimientos

## 🚀 Próximas Funcionalidades

<div align="center">

- [ ] Integración TensorFlow Lite con modelos reales (FaceNet/ArcFace)

### Grupo Whoami - Talento Tech- [ ] Dashboard con gráficas de estadísticas

- [ ] Exportación/importación de BD (JSON/CSV)

<img src="assets/images/fsociety_logo.png" alt="fsociety Logo" width="200"/>- [ ] Encriptación SQLCipher para BD

- [ ] Detección de vida (liveness detection)

*"Knowledge is free. We are Anonymous. We are Legion. We do not forgive. We do not forget. Expect us."*- [ ] Soporte para múltiples rostros en una imagen

- [ ] API REST local para integración externa

Un agradecimiento especial al **Grupo Whoami** del programa **Talento Tech** por el apoyo, mentoría y conocimientos compartidos durante el desarrollo de este proyecto.- [ ] Reconocimiento en video en tiempo real



**Miembros del equipo:**## 🔧 Tecnologías Utilizadas

- Instructores y mentores de Talento Tech

- Comunidad Whoami| Categoría | Tecnología |

- Colaboradores del proyecto|-----------|-----------|

| **Framework** | Flutter 3.9.2+ |

*Inspirados por Mr. Robot y la filosofía fsociety de compartir conocimiento libre y tecnología accesible para todos.*| **Lenguaje** | Dart 3.0+ |

| **Base de Datos** | SQLite 3.0 (sqflite) |

</div>| **Cámara** | camera ^0.10.5 |

| **Procesamiento Imagen** | image ^4.0.0 |

---| **IA (Preparado)** | TensorFlow Lite |

| **Arquitectura** | Clean Architecture + Singleton |

## 📧 Contacto| **Patrones** | Factory, Observer, Strategy |



- **Autor**: Brayan David Collazos Escobar## 🤝 Contribuir

- **GitHub**: [@Bdavid117](https://github.com/Bdavid117)

- **Email**: [tu-email@example.com]```bash

# 1. Fork el repositorio

---# 2. Crea tu rama

git checkout -b feature/nueva-funcionalidad

<div align="center">

# 3. Realiza cambios

**SIOMA** - Sistema Inteligente de Organización y Monitoreo Avanzado# 4. Ejecuta validaciones

flutter analyze

⭐ Si te gusta este proyecto, dale una estrella en GitHub!dart run lib/tools/biometric_diagnostic.dart



</div># 5. Commit con mensajes descriptivos

git commit -m "feat: agrega detección de vida"

# 6. Push y Pull Request
git push origin feature/nueva-funcionalidad
```

### Convenciones de Código

- ✅ **Dart conventions** - Linter habilitado
- ✅ **Clean Code** - Funciones < 50 líneas
- ✅ **Comentarios** - Documentación en funciones públicas
- ✅ **Error handling** - Try-catch con logging
- ✅ **Null safety** - Sound null safety habilitado

## 📄 Licencia

Este proyecto está bajo la **Licencia MIT**. Ver el archivo [`LICENSE`](./LICENSE) para más detalles.

---

## 🙏 Agradecimientos

- **Flutter Team** - Por el increíble framework
- **SQLite** - Base de datos más confiable del mundo
- **OpenCV / dlib** - Inspiración para algoritmos de visión

---

**Desarrollado con ❤️ usando Flutter** | **v1.0.0** | **Última actualización: Octubre 2025**
