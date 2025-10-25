# 🔬 Herramientas de Diagnóstico Biométrico - SIOMA

Esta carpeta contiene herramientas avanzadas para diagnosticar y resolver problemas en el sistema biométrico.

## 📁 Archivos

### `biometric_diagnostic.dart`
Herramienta de diagnóstico completo del sistema de reconocimiento biométrico.

**Uso:**
```bash
# Ejecutar desde la raíz del proyecto
dart run lib/tools/biometric_diagnostic.dart
```

**Diagnósticos realizados:**

#### 1️⃣ Verificación de Base de Datos
- ✅ Cuenta personas registradas
- ✅ Valida existencia de fotos
- ✅ Muestra fechas de registro

#### 2️⃣ Validación de Embeddings Almacenados
- ✅ Verifica formato JSON correcto
- ✅ Comprueba dimensiones (esperado: 512D)
- ✅ Detecta valores inválidos (NaN, infinitos, ceros)
- ✅ Calcula estadísticas (rango, media)
- ✅ Identifica embeddings corruptos

#### 3️⃣ Prueba de Determinismo
- ✅ Genera 3 embeddings de la misma imagen
- ✅ Verifica que sean idénticos (reproducibilidad)
- ✅ Compara con embedding almacenado en BD
- ✅ Detecta problemas de consistencia

#### 4️⃣ Simulación de Identificación 1:N
- ✅ Realiza búsqueda real contra BD
- ✅ Muestra top 5 candidatos con similitudes
- ✅ Verifica identificación correcta
- ✅ Recomienda ajustes de threshold

---

## 📊 Ejemplo de Salida

```
═══════════════════════════════════════════════════════════
🔬 DIAGNÓSTICO BIOMÉTRICO SIOMA
═══════════════════════════════════════════════════════════

📊 PASO 1: Verificando base de datos
─────────────────────────────────────
✅ Personas registradas: 3

👥 Listado de personas:
   1. Juan Pérez (12345)
      - Foto: /data/user/0/.../juan_12345.jpg
      - Registrado: 2025-10-24 10:30:00

🧬 PASO 2: Validando embeddings almacenados
─────────────────────────────────────────────
✅ Juan Pérez:
   - Dimensiones: 512
   - Rango: [-0.987, 0.921]
   - Media: 0.003

📈 Resumen de validación:
   ✅ Embeddings válidos: 3
   ❌ Embeddings inválidos: 0

🔬 PASO 3: Probando embeddings determinísticos
───────────────────────────────────────────────
🧪 Persona de prueba: Juan Pérez

   Generando 3 embeddings de la misma imagen...
   ✅ Embeddings IDÉNTICOS (determinístico)

   Comparando con embedding almacenado en BD...
   Similitud con BD: 98.75%
   ✅ Similitud alta (sistema funcionando)

🎯 PASO 4: Simulando identificación 1:N
─────────────────────────────────────────
🔍 Buscando: Juan Pérez

📊 Comparando contra 3 personas:

   🏆 Top 5 candidatos:
   ✅ 1. Juan Pérez: 98.75% [T65:✓ T50:✓]
      2. María López: 23.45% [T65:✗ T50:✗]
      3. Carlos Gómez: 18.92% [T65:✗ T50:✗]

📈 Análisis:
   ✅ Identificación CORRECTA
   Similitud: 98.75%
   ✅ Supera threshold 0.65 (OK)

═══════════════════════════════════════════════════════════
✅ Diagnóstico completado
═══════════════════════════════════════════════════════════
```

---

## 🔧 Resolución de Problemas

### ❌ Embeddings NO idénticos (no determinísticos)

**Problema:** Misma imagen genera embeddings diferentes

**Causa:** Uso de `Random()` con semillas variables en `face_embedding_service.dart`

**Solución:**
```dart
// ❌ INCORRECTO
final noise = Random().nextDouble();

// ✅ CORRECTO
final imageHash = _calculateImageHash(image);
final seedGenerator = Random(imageHash); // Seed fijo basado en imagen
```

---

### ⚠️ Similitud muy baja con BD

**Problema:** Similitud < 65% entre imagen nueva y BD

**Causas posibles:**
1. Embedding almacenado corrupto
2. Algoritmo cambió desde el registro
3. Imagen de baja calidad

**Soluciones:**
```bash
# 1. Re-registrar la persona
# 2. Reducir threshold temporalmente
threshold: 0.40

# 3. Verificar logs de generación
```

---

### ❌ Identificación incorrecta

**Problema:** Identifica a persona equivocada

**Diagnóstico:**
- Revisar similitudes de top 5 candidatos
- Si persona correcta está en top 5 pero no es #1:
  - Threshold muy alto
  - Embeddings similares entre personas

**Soluciones:**
- Capturar más fotos de mejor calidad
- Ajustar threshold: `0.40 - 0.55`
- Usar iluminación uniforme

---

## 💡 Mejores Prácticas

1. **Ejecutar después de cada cambio** en `face_embedding_service.dart`
2. **Validar determinismo** antes de desplegar
3. **Probar con múltiples personas** (mínimo 5)
4. **Documentar thresholds** óptimos por entorno
5. **Mantener logs** de diagnósticos históricos

---

## 🚀 Integración CI/CD

```yaml
# .github/workflows/test.yml
- name: Run Biometric Diagnostic
  run: |
    dart run lib/tools/biometric_diagnostic.dart
    # Parsear salida y fallar si hay embeddings inválidos
```

---

**Última actualización:** Octubre 2025
