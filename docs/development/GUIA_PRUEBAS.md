# 🧪 Guía de Pruebas - Sistema de Reconocimiento Biométrico

## 🎯 Objetivo

Esta guía te ayudará a verificar que el sistema de reconocimiento biométrico funciona correctamente después de las correcciones implementadas.

---

## ✅ Pre-requisitos

Antes de comenzar las pruebas, asegúrate de:

1. **Tener la app compilada:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Tener acceso a la cámara:**
   - En Android: Permisos de cámara otorgados
   - En Windows: Cámara web conectada

3. **Base de datos limpia (opcional):**
   ```bash
   # Si quieres empezar desde cero
   flutter run --clear-cache
   ```

---

## 🔬 Prueba 1: Diagnóstico Automático del Sistema

### Objetivo
Verificar que el sistema genera embeddings determinísticos y la BD está correcta.

### Pasos

```bash
# 1. Ejecutar diagnóstico desde terminal
dart run lib/tools/biometric_diagnostic.dart
```

### Resultados Esperados

```
═══════════════════════════════════════════════════════════
🔬 DIAGNÓSTICO BIOMÉTRICO SIOMA
═══════════════════════════════════════════════════════════

📊 PASO 1: Verificando base de datos
✅ Personas registradas: X

🧬 PASO 2: Validando embeddings almacenados
✅ Juan Pérez:
   - Dimensiones: 512
   - Rango: [-0.987, 0.921]
📈 Resumen de validación:
   ✅ Embeddings válidos: X
   ❌ Embeddings inválidos: 0  ⬅️ DEBE SER 0

🔬 PASO 3: Probando embeddings determinísticos
   ✅ Embeddings IDÉNTICOS (determinístico)  ⬅️ CRÍTICO
   Similitud con BD: 98.75%  ⬅️ DEBE SER >90%

🎯 PASO 4: Simulando identificación 1:N
   ✅ 1. Juan Pérez: 98.75% [T65:✓ T50:✓]
📈 Análisis:
   ✅ Identificación CORRECTA  ⬅️ CRÍTICO
```

### ✅ Criterios de Éxito
- [ ] Embeddings son **IDÉNTICOS** (determinísticos)
- [ ] Similitud con BD > **90%**
- [ ] Identificación **CORRECTA**
- [ ] 0 embeddings inválidos

### ❌ Si Falla
1. **Embeddings NO idénticos:**
   - Verificar que no haya `Random()` en `face_embedding_service.dart`
   - Re-compilar: `flutter clean && flutter run`

2. **Similitud < 90%:**
   - Re-registrar la persona desde cero
   - Verificar que la foto exista en disco

3. **Identificación incorrecta:**
   - Reducir threshold a 0.40
   - Verificar logs en consola

---

## 👤 Prueba 2: Registro de Persona Nueva

### Objetivo
Verificar el flujo completo de registro biométrico.

### Pasos

1. **Abrir la app** y ir al tab **"Registro"**

2. **Llenar datos:**
   - Nombre: `Test Usuario`
   - Documento: `TEST001`

3. **Capturar foto:**
   - Hacer clic en "Capturar Foto"
   - Posicionar rostro en el círculo guía
   - Tomar foto

4. **Verificar embedding:**
   - Debe mostrar: `Características biométricas generadas correctamente (512D)`

5. **Confirmar registro:**
   - Hacer clic en "Registrar Persona"
   - Debe mostrar: `✅ Persona registrada exitosamente`

### ✅ Criterios de Éxito
- [ ] Foto se captura correctamente
- [ ] Embedding generado: **512D**
- [ ] Registro exitoso sin errores
- [ ] Persona aparece en tab "Personas"

### ❌ Si Falla
- **Error de cámara:** Verificar permisos
- **Embedding vacío:** Revisar `face_embedding_service.dart`
- **Error de BD:** Verificar `database_service.dart`

---

## 🔍 Prueba 3: Identificación de Persona Registrada

### Objetivo
Verificar que el sistema reconoce correctamente a personas registradas.

### Pasos

1. **Ir al tab "Identificación Avanzada"**

2. **Capturar foto:**
   - Hacer clic en botón de cámara
   - Tomar foto de **persona ya registrada**

3. **Observar logs en consola:**
   ```
   🔍 Iniciando identificación 1:N
   📊 Umbral de confianza: 50.0%
   👥 Comparando contra X personas registradas
   📊 Test Usuario: cosine=85.3%, euclidean=78.2%, combined=83.1%
   ✅ Identificado: Test Usuario con 83.1%
   ```

4. **Verificar resultado en UI:**
   - Debe mostrar: Nombre de la persona
   - Confianza: **> 50%**
   - Estado: **Identificado ✅**

### ✅ Criterios de Éxito
- [ ] Identificación **correcta** (persona registrada)
- [ ] Confianza **> 50%**
- [ ] Tiempo de respuesta **< 5 segundos**
- [ ] Logs muestran similitudes altas

### ❌ Si Falla

#### No reconoce (confianza < 50%)
```bash
# 1. Ejecutar diagnóstico
dart run lib/tools/biometric_diagnostic.dart

# 2. Verificar similitudes en logs
# Si similitudes < 50%, reducir threshold:
```

En `identification_service.dart`:
```dart
threshold: 0.40, // Reducir de 0.50 a 0.40
```

#### Identifica persona incorrecta
- Verificar que las fotos sean de buena calidad
- Asegurarse de que no haya personas muy similares
- Revisar top 3 candidatos en logs

---

## ❌ Prueba 4: Persona No Registrada

### Objetivo
Verificar manejo de personas desconocidas.

### Pasos

1. **Ir a "Identificación Avanzada"**

2. **Capturar foto de persona NO registrada:**
   - Puede ser otra persona
   - O foto de internet

3. **Verificar resultado:**
   - Debe mostrar: **"Persona No Registrada"**
   - Debe ofrecer botón: **"Registrar Persona"**

4. **Hacer clic en "Registrar Persona":**
   - Debe navegar al **tab de Registro** (índice 0)
   - Debe mantener la foto capturada

### ✅ Criterios de Éxito
- [ ] Detecta correctamente **persona no registrada**
- [ ] Botón "Registrar Persona" funciona
- [ ] Navega al tab correcto
- [ ] No hay errores en consola

### ❌ Si Falla
- **Identifica erróneamente:** Threshold muy bajo, subir a 0.55
- **Botón no funciona:** Verificar `advanced_identification_screen.dart`
- **No navega:** Revisar `DefaultTabController.of(context).animateTo(0)`

---

## 📊 Prueba 5: Identificación Múltiple

### Objetivo
Verificar rendimiento con múltiples personas.

### Pasos

1. **Registrar 5 personas diferentes:**
   - Persona 1: Tu rostro
   - Persona 2: Familiar/amigo
   - Persona 3: Foto de internet 1
   - Persona 4: Foto de internet 2
   - Persona 5: Foto de internet 3

2. **Probar identificación de cada una:**
   - Ir a "Identificación Avanzada"
   - Capturar foto de Persona 1
   - Verificar identificación correcta
   - Repetir para Persona 2, 3, 4, 5

3. **Verificar estadísticas:**
   - Ir al tab "Personas"
   - Verificar que hay 5 personas
   - Revisar fechas de registro

4. **Medir rendimiento:**
   - Tiempo de identificación < 5 segundos
   - Tasa de éxito: 4/5 o 5/5 (80-100%)

### ✅ Criterios de Éxito
- [ ] Identifica correctamente **≥ 80%** de las personas
- [ ] Tiempo promedio **< 5 segundos**
- [ ] No hay crashes ni errores
- [ ] Logs muestran similitudes consistentes

### ❌ Si Falla
- **Tasa < 80%:** Mejorar calidad de fotos, ajustar threshold
- **Tiempo > 5s:** Verificar número de personas en BD (límite: 1000)
- **Crashes:** Revisar logs de errores

---

## 🎯 Prueba 6: Casos Extremos

### Objetivo
Verificar robustez del sistema.

### Casos a Probar

#### 1. Foto muy oscura
- Capturar en ambiente con poca luz
- Debe rechazar o advertir

#### 2. Foto muy brillante
- Capturar con luz directa/flash
- Debe rechazar o advertir

#### 3. Rostro parcialmente oculto
- Capturar con lentes de sol, gorro, mascarilla
- Debe tener confianza baja (<50%)

#### 4. Foto borrosa
- Mover la cámara al capturar
- Debe rechazar o confianza baja

#### 5. Sin rostro
- Capturar objeto, paisaje
- Debe fallar gracefully

### ✅ Criterios de Éxito
- [ ] No hay crashes en casos extremos
- [ ] Mensajes de error claros
- [ ] Sistema se recupera correctamente

---

## 📈 Resultados Esperados

### Métricas de Éxito

| Métrica | Objetivo | Aceptable | Crítico |
|---------|----------|-----------|---------|
| **Tasa de identificación correcta** | >90% | >80% | >70% |
| **Tiempo de respuesta** | <3s | <5s | <10s |
| **Falsos positivos** | <5% | <10% | <20% |
| **Falsos negativos** | <10% | <20% | <30% |
| **Similitud promedio (correcto)** | >80% | >70% | >60% |
| **Similitud promedio (incorrecto)** | <30% | <40% | <50% |

---

## 🐛 Registro de Problemas

Si encuentras problemas, documenta:

```markdown
### Problema #X

**Descripción:** [Qué pasó]

**Pasos para reproducir:**
1. [Paso 1]
2. [Paso 2]

**Resultado esperado:** [Qué debería pasar]

**Resultado actual:** [Qué pasó realmente]

**Logs:**
```
[Pegar logs de consola]
```

**Screenshots:** [Adjuntar si es posible]

**Severidad:** 🔴 Crítica / 🟡 Media / 🟢 Baja
```

---

## ✅ Checklist Final

Después de completar todas las pruebas:

- [ ] ✅ Diagnóstico automático pasa (embeddings determinísticos)
- [ ] ✅ Registro de personas funciona
- [ ] ✅ Identificación de registradas funciona (>80%)
- [ ] ✅ Detección de no registradas funciona
- [ ] ✅ Botón "Registrar Persona" navega correctamente
- [ ] ✅ Prueba con 5+ personas exitosa
- [ ] ✅ Casos extremos manejados sin crashes
- [ ] ✅ Rendimiento aceptable (<5s por identificación)
- [ ] ✅ Sin errores críticos en logs

---

## 📝 Reporte de Pruebas

Al finalizar, completa:

```markdown
## Reporte de Pruebas - [Fecha]

**Ambiente:**
- Dispositivo: [Android/iOS/Windows]
- Flutter version: [flutter --version]
- Personas registradas: [N]

**Resultados:**
- Diagnóstico automático: ✅ / ❌
- Tasa de identificación: X/Y (XX%)
- Tiempo promedio: Xs
- Falsos positivos: X
- Falsos negativos: X

**Problemas encontrados:**
1. [Problema #1]
2. [Problema #2]

**Conclusión:** ✅ Sistema funcional / ⚠️ Requiere ajustes / ❌ No funcional

**Recomendaciones:**
- [Recomendación 1]
- [Recomendación 2]
```

---

**Última actualización:** Octubre 2025  
**Versión de pruebas:** 1.0.0
