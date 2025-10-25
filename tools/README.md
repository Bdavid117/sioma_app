# 🛠️ Herramientas de Validación y Diagnóstico - SIOMA

Esta carpeta contiene scripts de diagnóstico y validación para el desarrollo y mantenimiento del sistema SIOMA.

## 📁 Archivos

### `test_fixes.dart`
Script de validación para verificar correcciones implementadas en el código base.

**Uso:**
```bash
dart run tools/test_fixes.dart
```

**Verifica:**
- ✅ Correcciones de bugs conocidos
- ✅ Validaciones de seguridad
- ✅ Integridad de datos

---

### `validate_fixes.dart`
Herramienta de validación completa del sistema después de aplicar correcciones.

**Uso:**
```bash
dart run tools/validate_fixes.dart
```

**Valida:**
- ✅ Base de datos SQLite
- ✅ Modelos de datos
- ✅ Servicios core
- ✅ Pantallas principales

---

### `validate_capture_fixes.dart`
Validación específica para correcciones del sistema de captura de cámara.

**Uso:**
```bash
dart run tools/validate_capture_fixes.dart
```

**Prueba:**
- ✅ Servicio de cámara
- ✅ Permisos
- ✅ Gestión de archivos multimedia
- ✅ Integración con embeddings

---

## 🚀 Ejecución Rápida

```bash
# Ejecutar todos los validadores en secuencia
dart run tools/test_fixes.dart
dart run tools/validate_fixes.dart
dart run tools/validate_capture_fixes.dart
```

## 📝 Notas

- Estos scripts están diseñados para **desarrollo y testing**
- No deben incluirse en builds de producción
- Requieren acceso al código fuente completo
- Útiles para CI/CD pipelines

---

**Última actualización:** Octubre 2025
