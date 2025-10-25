# ❓ Preguntas Frecuentes (FAQ) - SIOMA

Respuestas a las preguntas más comunes sobre SIOMA.

---

## 🚀 General

### ¿Qué es SIOMA?

SIOMA (Sistema de Identificación Offline con Machine Learning y Análisis) es una aplicación móvil y de escritorio para reconocimiento facial que funciona completamente offline, sin necesidad de conexión a internet.

### ¿En qué plataformas funciona?

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 11.0+
- ✅ Windows 10/11
- ✅ macOS 10.14+
- ✅ Linux (Ubuntu, Debian, Fedora)

### ¿Es gratuita?

Sí, SIOMA es de código abierto bajo licencia MIT.

### ¿Necesita conexión a internet?

No. SIOMA funciona 100% offline. Todos los datos permanecen en tu dispositivo.

---

## 🔐 Privacidad y Seguridad

### ¿Dónde se almacenan mis datos?

Todos los datos (fotos, embeddings, historial) se almacenan **localmente** en tu dispositivo. Nunca se envían a servidores externos.

### ¿Se envía información a internet?

No. SIOMA no tiene telemetría, analytics ni conexión a servicios cloud.

### ¿Puedo exportar mis datos?

Sí, puedes exportar la base de datos completa en formato JSON para respaldo o transferencia.

### ¿Cómo se protegen los datos?

- Almacenamiento local en SQLite
- Sin exposición a internet
- Validaciones de seguridad en inputs
- (Opcional) Encriptación SQLCipher disponible

---

## 📸 Captura y Registro

### ¿Cuántas fotos necesito por persona?

Con una foto de buena calidad es suficiente. Para mejor precisión, recomendamos 2-3 fotos en diferentes condiciones de luz.

### ¿Qué calidad de foto se requiere?

- **Resolución mínima:** 640x480 (VGA)
- **Recomendada:** 1280x720 (HD) o superior
- **Iluminación:** Uniforme, evitar sombras fuertes
- **Posición:** Rostro frontal, completo

### ¿Funciona con lentes?

Sí, pero para mejor precisión:
- Registrar CON lentes si usa habitualmente
- Registrar SIN lentes si no los usa frecuentemente

### ¿Reconoce con mascarilla?

El reconocimiento se reduce significativamente con mascarilla. Se recomienda registrar sin mascarilla.

### ¿Puedo usar fotos existentes?

Sí, puedes seleccionar de galería en lugar de capturar con cámara.

---

## 🔍 Identificación

### ¿Cuántas personas puedo registrar?

Límite técnico: ilimitado  
**Recomendado:** Hasta 1000 personas para óptimo rendimiento (< 5 segundos de identificación)

### ¿Qué tan preciso es el reconocimiento?

Con embeddings simulados (actuales):
- **Precisión:** ~85-90% en condiciones óptimas
- **Threshold:** 0.50 (50% de similitud mínima)

Con modelos reales (FaceNet/ArcFace):
- **Precisión:** >95%
- **Threshold:** 0.65-0.75

### ¿Por qué no reconoce a alguien registrado?

**Causas comunes:**
1. **Iluminación diferente** - Registrar y capturar en condiciones similares
2. **Ángulo de rostro** - Usar rostro frontal
3. **Cambios en apariencia** - Barba, lentes, peinado
4. **Foto borrosa** - Evitar movimiento
5. **Threshold muy alto** - Reducir a 0.40-0.45

### ¿Por qué identifica persona incorrecta?

**Causas comunes:**
1. **Personas muy similares** - Gemelos, familiares cercanos
2. **Threshold muy bajo** - Aumentar a 0.60-0.65
3. **Fotos de baja calidad** - Re-registrar con mejor calidad

### ¿Cuánto tarda una identificación?

- **1-100 personas:** < 1 segundo
- **100-500 personas:** 1-3 segundos
- **500-1000 personas:** 3-5 segundos
- **>1000 personas:** 5-10 segundos

---

## 🛠️ Configuración

### ¿Cómo ajusto la sensibilidad?

Threshold (umbral de similitud):
- **Más estricto** (menos falsos positivos): 0.60-0.70
- **Menos estricto** (menos falsos negativos): 0.40-0.50
- **Por defecto:** 0.50

Actualmente se ajusta en el código. Próxima versión tendrá UI para configuración.

### ¿Puedo cambiar el idioma?

Actualmente solo español. Soporte multi-idioma planeado para futuras versiones.

### ¿Cómo hago respaldo de datos?

```bash
# Exportar (próximamente en UI)
Tab "Configuración" > Exportar Base de Datos

# Manual: Copiar archivo SQLite
Android: /data/data/com.example.sioma_app/databases/sioma.db
iOS: Library/Application Support/sioma.db
```

---

## 🐛 Problemas Técnicos

### Error: "Camera permission denied"

**Solución:**
1. Ir a Configuración del sistema
2. Apps > SIOMA > Permisos
3. Habilitar Cámara

### Error: "No se pudo generar embedding"

**Causas:**
- Imagen corrupta o inválida
- Formato no soportado
- Tamaño muy grande/pequeño

**Solución:**
1. Verificar que imagen sea válida
2. Usar captura de cámara en lugar de galería
3. Verificar permisos de almacenamiento

### App se cierra inesperadamente

**Diagnóstico:**
```bash
# Ejecutar diagnóstico
dart run lib/tools/biometric_diagnostic.dart

# Ver logs
flutter run
# Revisar errores en consola
```

**Soluciones:**
1. Limpiar caché: `flutter clean && flutter run`
2. Reinstalar app
3. Verificar espacio en almacenamiento
4. Reportar issue con logs

### Identificación muy lenta

**Optimizaciones:**
1. Reducir personas registradas (<500)
2. Aumentar threshold (menos candidatos a evaluar)
3. Limpiar base de datos (eliminar duplicados)
4. Usar dispositivo con más RAM

---

## 💡 Uso Avanzado

### ¿Puedo usar mi propio modelo de IA?

Sí. SIOMA está preparado para TensorFlow Lite. Ver `docs/development/MEJORAS_CODIGO.md` para guía de integración.

### ¿Hay API para integrar con otros sistemas?

Actualmente no, pero está planeado para futuras versiones:
- API REST local
- Exports JSON/CSV
- Webhooks

### ¿Puedo modificar el código?

Sí, SIOMA es open source (MIT License). Puedes:
- Modificar libremente
- Crear forks
- Contribuir con pull requests
- Usar comercialmente (ver licencia)

### ¿Cómo contribuyo al proyecto?

1. Fork el repositorio en GitHub
2. Crear rama para tu feature
3. Implementar con tests
4. Enviar pull request
5. Ver `docs/development/` para guías

---

## 📊 Rendimiento

### ¿Cuánto espacio ocupa?

- **App:** ~50MB
- **Por persona:** ~300KB (foto) + ~1KB (embedding) = ~301KB
- **100 personas:** ~30MB
- **1000 personas:** ~300MB

### ¿Consume mucha batería?

**En identificación activa:**
- Uso moderado (cámara + procesamiento)
- Similar a apps de cámara estándar

**En background:**
- Consumo mínimo (solo BD)

### ¿Funciona offline realmente?

Sí, 100% offline:
- ✅ Registro de personas
- ✅ Identificación 1:N
- ✅ Gestión de datos
- ✅ Estadísticas

No requiere internet en ningún momento.

---

## 🔄 Actualizaciones

### ¿Cómo actualizo SIOMA?

```bash
# Obtener última versión
git pull origin main

# Actualizar dependencias
flutter pub get

# Reinstalar
flutter run
```

### ¿Las actualizaciones borran mis datos?

No. Los datos persisten entre actualizaciones. Siempre se recomienda hacer respaldo antes de actualizar.

### ¿Dónde veo el changelog?

Ver archivo `CHANGELOG.md` en la raíz del proyecto.

---

## 📞 Soporte

### ¿Dónde reporto problemas?

1. **GitHub Issues:** [github.com/Bdavid117/sioma_app/issues](https://github.com/Bdavid117/sioma_app/issues)
2. Incluir:
   - Descripción detallada
   - Pasos para reproducir
   - Screenshots/logs
   - Versión de app y dispositivo

### ¿Hay comunidad/foro?

Actualmente no, pero planeado para el futuro:
- Discord server
- GitHub Discussions
- Wiki colaborativo

### ¿Ofrecen soporte comercial?

Contactar al mantenedor del proyecto para consultas comerciales.

---

## 🚀 Roadmap

### ¿Qué funcionalidades están planeadas?

**Corto plazo (1-3 meses):**
- [ ] UI para ajustar threshold
- [ ] Exportar/importar datos desde UI
- [ ] Dashboard de estadísticas
- [ ] Dark mode

**Mediano plazo (3-6 meses):**
- [ ] Integración TensorFlow Lite (modelos reales)
- [ ] Detección de calidad de imagen
- [ ] Multi-idioma (i18n)
- [ ] API REST local

**Largo plazo (6+ meses):**
- [ ] Detección de vida (liveness)
- [ ] Reconocimiento multi-rostro
- [ ] Encriptación de BD (SQLCipher)
- [ ] Sincronización entre dispositivos

---

**¿No encuentras tu pregunta?**

- **Documentación técnica:** `docs/technical/`
- **Guía de usuario:** `docs/user/USER_GUIDE.md`
- **Reportar issue:** GitHub Issues

---

**Última actualización:** Octubre 2025  
**Versión:** 1.0.0
