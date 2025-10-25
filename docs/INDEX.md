# 📚 Documentación SIOMA - Índice Principal

Bienvenido a la documentación completa del Sistema de Identificación Offline con Machine Learning y Análisis (SIOMA).

---

## 🚀 Inicio Rápido

**Para usuarios nuevos, comenzar aquí:**

1. **[README.md](../README.md)** - Vista general del proyecto
2. **[Instalación y Configuración](./setup/INSTALLATION.md)** - Guía de instalación paso a paso
3. **[Guía de Usuario](./user/USER_GUIDE.md)** - Cómo usar la aplicación
4. **[FAQ](./user/FAQ.md)** - Preguntas frecuentes

---

## 📖 Documentación Técnica

### Arquitectura y Diseño

| Documento | Descripción |
|-----------|-------------|
| **[FASE_1_BASE_DATOS.md](./technical/FASE_1_BASE_DATOS.md)** | SQLite, modelos de datos, CRUD |
| **[FASE_2_CAMARA.md](./technical/FASE_2_CAMARA.md)** | Sistema de captura biométrica |
| **[FASE_3_EMBEDDINGS.md](./technical/FASE_3_EMBEDDINGS.md)** | Generación de vectores faciales |
| **[FASE_4_REGISTRO.md](./technical/FASE_4_REGISTRO.md)** | Proceso de enrollment |
| **[FASE_5_IDENTIFICACION.md](./technical/FASE_5_IDENTIFICACION.md)** | Sistema 1:N completo |

### Guías de Desarrollo

| Documento | Descripción |
|-----------|-------------|
| **[MEJORAS_CODIGO.md](./development/MEJORAS_CODIGO.md)** | Sugerencias de mejora priorizadas |
| **[SEGURIDAD.md](./development/SEGURIDAD.md)** | Medidas de seguridad implementadas |
| **[TESTING.md](./development/TESTING.md)** | Estrategia de testing |
| **[GUIA_PRUEBAS.md](./development/GUIA_PRUEBAS.md)** | Guía completa de pruebas manuales |

---

## 🧪 Testing

### Tests Automatizados

- **[Tests Unitarios](../test/)** - Tests de services y modelos
- **[Tests de Integración](../integration_test/)** - Tests E2E del sistema
- **[Herramienta de Diagnóstico](../lib/tools/biometric_diagnostic.dart)** - Diagnóstico automatizado

### Ejecutar Tests

```bash
# Tests unitarios
flutter test

# Tests de integración
flutter test integration_test/

# Diagnóstico biométrico
dart run lib/tools/biometric_diagnostic.dart
```

---

## 🛠️ Herramientas

| Herramienta | Ubicación | Descripción |
|-------------|-----------|-------------|
| **Diagnóstico Biométrico** | `lib/tools/biometric_diagnostic.dart` | Verifica embeddings y similitudes |
| **Scripts de Validación** | `tools/` | Scripts de testing manual |
| **Logger** | `lib/utils/app_logger.dart` | Sistema de logging estructurado |

---

## 📋 Changelog

**[CHANGELOG.md](../CHANGELOG.md)** - Historial completo de cambios

---

## 🗂️ Estructura de Documentación

```
docs/
├── INDEX.md                    # Este archivo
├── setup/                      # Instalación y configuración
│   ├── INSTALLATION.md
│   └── CONFIGURATION.md
├── user/                       # Documentación de usuario
│   ├── USER_GUIDE.md
│   └── FAQ.md
├── technical/                  # Documentación técnica
│   ├── FASE_1_BASE_DATOS.md
│   ├── FASE_2_CAMARA.md
│   ├── FASE_3_EMBEDDINGS.md
│   ├── FASE_4_REGISTRO.md
│   └── FASE_5_IDENTIFICACION.md
├── development/                # Guías de desarrollo
│   ├── MEJORAS_CODIGO.md
│   ├── SEGURIDAD.md
│   ├── TESTING.md
│   └── GUIA_PRUEBAS.md
└── archive/                    # Documentos antiguos
    └── README.md (antiguo)
```

---

## 📞 Soporte

- **Issues**: Reportar en el repositorio GitHub
- **Documentación**: Buscar en este índice
- **Ejemplos**: Ver `docs/technical/` y `docs/development/TESTING.md`

---

**Última actualización:** Octubre 2025  
**Versión:** 1.0.0
