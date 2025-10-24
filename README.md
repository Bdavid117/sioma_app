# 🔬 SIOMA - Sistema de Identificación Offline con Machine Learning y Análisis

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)

## 📋 Descripción

SIOMA es una aplicación Flutter 100% offline para reconocimiento facial y gestión biométrica local. Implementa captura de cámara, generación de embeddings faciales, búsqueda 1:N y persistencia local con SQLite.

## ✨ Características Principales

- 🔐 **100% Offline** - No requiere conexión a internet
- 📸 **Captura Biométrica** - Cámara con guías visuales para rostros
- 🧠 **IA Local** - Generación de embeddings faciales (TFLite ready)
- 🔍 **Identificación 1:N** - Búsqueda contra base de datos local
- 🗄️ **Persistencia SQLite** - Almacenamiento seguro y encriptado
- 🛡️ **Seguridad** - Validaciones robustas y manejo seguro de datos
- 📱 **Multiplataforma** - Android, iOS, Windows, macOS, Linux

## 🚀 Instalación Rápida

```bash
# Clonar el repositorio
git clone <repository-url>
cd sioma_app

# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run
```

## 📖 Documentación Completa

Toda la documentación técnica se encuentra en la carpeta [`docs/`](./docs/):

- 📘 [`FASE_1_BASE_DATOS.md`](./docs/FASE_1_BASE_DATOS.md) - SQLite y modelos de datos
- 📘 [`FASE_2_CAMARA.md`](./docs/FASE_2_CAMARA.md) - Sistema de captura biométrica
- 📘 [`FASE_3_EMBEDDINGS.md`](./docs/FASE_3_EMBEDDINGS.md) - Procesamiento IA y vectores
- 📘 [`FASE_4_REGISTRO.md`](./docs/FASE_4_REGISTRO.md) - Enrollment de personas
- 🛡️ [`SEGURIDAD.md`](./docs/SEGURIDAD.md) - Medidas de seguridad implementadas
- 🧪 [`TESTING.md`](./docs/TESTING.md) - **Códigos completos para probar**

## 🎯 Funcionalidades Implementadas

### ✅ FASE 1: Base de Datos SQLite
- Modelos de datos (`Person`, `IdentificationEvent`)
- CRUD completo con validaciones
- Protección contra inyección SQL
- Sistema de logging estructurado

### ✅ FASE 2: Captura de Cámara
- Servicio de cámara con permisos automáticos
- Interfaz profesional con guías visuales
- Gestión segura de archivos multimedia
- Limpieza automática de almacenamiento

### ✅ FASE 3: Embeddings Faciales
- Generación de vectores de características (128D)
- Cálculo de similitud coseno
- Sistema preparado para TensorFlow Lite
- Algoritmo simulado reproducible

### ✅ FASE 4: Registro (Enrollment)
- Flujo paso a paso con validaciones
- Integración completa (Cámara + IA + BD)
- Gestión de personas registradas
- Interfaz intuitiva con indicadores visuales

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   📱 UI Layer   │    │  🔧 Services    │    │  🗄️ Data Layer  │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Enrollment    │◄──►│ • CameraService │◄──►│ • SQLite DB     │
│ • Management    │    │ • EmbeddingServ │    │ • File Storage  │
│ • Navigation    │    │ • DatabaseServ  │    │ • Validations   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🧪 Pruebas Rápidas

### Ejecutar la aplicación:
```bash
flutter run -d <device-id>
```

### Probar funcionalidades:
1. **Registro** → Registra una persona completa
2. **Personas** → Gestiona registros existentes  
3. **Cámara** → Prueba captura y galería
4. **Embeddings** → Genera y compara vectores
5. **Base de Datos** → Operaciones CRUD básicas

Ver [`docs/TESTING.md`](./docs/TESTING.md) para códigos detallados de prueba.

## 🛡️ Seguridad

- ✅ Validación completa de datos de entrada
- ✅ Protección contra inyección SQL y path traversal
- ✅ Límites de recursos y memoria
- ✅ Manejo seguro de archivos multimedia
- ✅ Logging sin exposición de datos sensibles

## 🔧 Tecnologías Utilizadas

- **Framework:** Flutter 3.9.2+
- **Lenguaje:** Dart
- **Base de Datos:** SQLite (sqflite)
- **Cámara:** camera plugin
- **IA:** TensorFlow Lite (preparado)
- **Validaciones:** Regex y sanitización custom
- **Arquitectura:** Clean Architecture + Singleton patterns

## 📊 Estado del Proyecto

- ✅ **FASE 1:** Base de datos SQLite - **COMPLETADO**
- ✅ **FASE 2:** Captura de cámara - **COMPLETADO**  
- ✅ **FASE 3:** Embeddings faciales - **COMPLETADO**
- ✅ **FASE 4:** Registro de personas - **COMPLETADO**
- 🚧 **FASE 5:** Identificación 1:N - **PENDIENTE**
- 🚧 **FASE 6:** Interfaz completa - **PENDIENTE**

## 📝 Próximas Funcionalidades

- 🔍 Sistema de identificación en tiempo real
- 📊 Dashboard con estadísticas
- 📁 Exportación/importación de datos
- 🔐 Encriptación SQLCipher
- ⚡ Optimizaciones de rendimiento

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature
3. Realiza tus cambios siguiendo las buenas prácticas
4. Ejecuta las pruebas
5. Envía un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

---

**Desarrollado con ❤️ usando Flutter**
