# 🚀 Guía de Ejecución - SIOMA v2.0

## Pasos para Ejecutar y Probar

### 1. Preparación

```bash
# Asegúrate de estar en el directorio del proyecto
cd C:\Users\BrayanDavidCollazosE\StudioProjects\sioma_app

# Actualizar dependencias
flutter pub get

# Verificar que todo compile
flutter analyze
```

### 2. Conectar Dispositivo

#### Opción A: Dispositivo Android Físico (RECOMENDADO)

```bash
# Ver dispositivos conectados
flutter devices

# Deberías ver algo como:
# 24094RAD4G (mobile) • ORFUGAG6FEZTYLFU • android-arm64 • Android 15 (API 35)
```

#### Opción B: Emulador

```bash
# Ver emuladores disponibles
flutter emulators

# Iniciar un emulador
flutter emulators --launch <nombre_emulador>
```

### 3. Ejecutar la Aplicación

```bash
# En dispositivo físico específico
flutter run -d 24094RAD4G

# O simplemente (si solo hay un dispositivo)
flutter run

# Para ver logs detallados
flutter run -v
```

### 4. Probar la Captura Inteligente

#### Test 1: Registro de Persona

1. **Abrir la app** en tu dispositivo
2. **Ir a la pestaña "Registrar"** (primera tab)
3. **Completar datos**:
   - Nombre: `Juan Pérez`
   - Documento: `12345678`
4. **Tocar "Capturar Foto"**
5. **Observar el sistema inteligente**:
   - Se abre SmartCameraCaptureScreen
   - Verás indicadores de calidad en tiempo real
   - Posiciona tu rostro en el óvalo
   - Espera 3-5 segundos
   - **El sistema capturará automáticamente** cuando detecte 3 frames óptimos
6. **Revisar el preview**:
   - Verás análisis de calidad (Score, Nitidez, Iluminación, Contraste)
   - Si está bien, toca "Usar Esta Foto"
   - Si no, toca "Rechazar" y vuelve a intentar
7. **Guardar** la persona

#### Test 2: Calidad de Foto

**Prueba en diferentes condiciones**:

**Test A - Iluminación Baja**:
- Ubícate en un lugar oscuro
- Observa: El sistema mostrará "💡 Aumenta la iluminación"
- No capturará hasta que mejore la luz

**Test B - Movimiento/Blur**:
- Mueve la cámara rápidamente
- Observa: El sistema mostrará "📸 Mantén la cámara estable"
- No capturará fotos borrosas

**Test C - Condiciones Óptimas**:
- Buena iluminación natural o artificial
- Cámara estable
- Rostro centrado en el óvalo
- Observa: Verás "✨ Excelente! Calidad: 85% (1/3)" → (2/3) → (3/3) → **¡Captura!**

#### Test 3: Modo Manual

1. Durante la captura, toca el ícono ⚡ (auto-awesome)
2. Cambia a modo manual
3. Ahora puedes capturar presionando el botón "Capturar Foto"
4. Útil si quieres tener control total

#### Test 4: Identificación

1. **Registra 2-3 personas** con fotos de calidad
2. **Ir a la pestaña "Identificar"**
3. **Tomar nueva foto** de una persona registrada
4. **Verificar reconocimiento**:
   - Antes (fotos manuales): ~60-70% confianza
   - Ahora (fotos inteligentes): ~80-90% confianza
   - ¡Deberías ver mejor precisión!

### 5. Ver Logs en Tiempo Real

#### En la terminal donde ejecutaste flutter run:

```
📸 [CAMERA] Cámara inicializada correctamente
✅ [CAMERA] Análisis de calidad: 85% - Excelente
🔬 [BIOMETRIC] 🔍 Identificación 1:N iniciada
✅ [BIOMETRIC] Persona identificada: Juan Pérez (89.5% confianza)
```

#### Para ver solo logs de calidad:

```bash
# En otra terminal
flutter logs | Select-String "CAMERA|calidad|Análisis"
```

### 6. Depuración (si algo falla)

#### Problema: "Cámara no disponible"

```bash
# Verificar permisos de cámara en el dispositivo:
# Configuración → Apps → SIOMA → Permisos → Cámara: ✅ Permitido
```

#### Problema: "No captura automáticamente"

Posibles causas:
- Iluminación insuficiente (< 30%)
- Foto borrosa (nitidez < 50%)
- Bajo contraste

**Solución**:
- Mejora la iluminación
- Mantén la cámara estable
- Usa un fondo con contraste

#### Problema: "Reconocimiento bajo"

Si después de captura inteligente aún es bajo:
- Verifica que la persona esté registrada
- Re-registra con mejor iluminación
- Ajusta threshold en `identification_service.dart` si es necesario

### 7. Hot Reload Durante Desarrollo

Si estás modificando código:

```bash
# En la terminal donde corre la app:
r  # Hot reload (recarga rápida sin reiniciar)
R  # Hot restart (reinicio completo)
```

### 8. Build para Producción

```bash
# Android APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (para Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 9. Instalar APK en Dispositivo

```bash
# Después del build
flutter install --release

# O manualmente
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 🎯 Checklist de Pruebas

- [ ] App inicia correctamente
- [ ] Cámara se abre sin errores
- [ ] Indicadores de calidad se muestran en tiempo real
- [ ] Captura automática funciona (3 frames óptimos)
- [ ] Preview muestra análisis de calidad
- [ ] Modo manual funciona como respaldo
- [ ] Persona se guarda en base de datos
- [ ] Identificación reconoce personas registradas
- [ ] Confianza de reconocimiento es alta (>80%)
- [ ] Eventos se registran correctamente

## 📊 Métricas Esperadas

### Captura Inteligente

| Métrica | Valor Esperado |
|---------|----------------|
| Tiempo hasta captura | 3-5 segundos |
| Frames analizados hasta captura | ~6-10 frames |
| Score de calidad mínimo | 75% |
| Frames óptimos consecutivos | 3 |

### Reconocimiento

| Métrica | Antes | Ahora |
|---------|-------|-------|
| Confianza promedio | ~60-70% | ~80-90% |
| Tasa de falsos negativos | ~20-30% | ~5-10% |
| Calidad de fotos | Variable | Alta garantizada |

## 🐛 Troubleshooting Común

### Error: "pubspec.yaml has changed"

```bash
flutter pub get
```

### Error: "Gradle build failed"

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Error: "Camera permission denied"

1. En el dispositivo: Configuración → Apps → SIOMA → Permisos
2. Activar permiso de Cámara
3. Reiniciar la app

## 📝 Notas Finales

- **Primera ejecución**: Puede tardar 2-3 minutos compilando
- **Hot reload**: Cambios en código aplican en ~1 segundo
- **Dispositivo físico**: Siempre preferible para testing de cámara
- **Logs**: Revísalos para entender el flujo del sistema

---

**¿Listo para probarlo?** 🚀

```bash
flutter run -d 24094RAD4G
```

¡Disfruta del nuevo sistema de captura inteligente!
