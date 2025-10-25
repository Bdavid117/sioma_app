# 📱 Guía de Usuario - SIOMA

Guía completa para usar el Sistema de Identificación Offline con Machine Learning y Análisis.

---

## 🎯 Visión General

SIOMA es una aplicación de reconocimiento facial que funciona completamente offline. Permite registrar personas y luego identificarlas automáticamente usando la cámara de tu dispositivo.

---

## 🚀 Inicio Rápido (5 minutos)

### Paso 1: Registrar Primera Persona

1. **Abrir la app** SIOMA
2. **Ir al tab "Registro"** (ícono de persona con +)
3. **Llenar datos:**
   - Nombre: "Juan Pérez"
   - Documento: "12345678"
4. **Hacer clic en "Capturar Foto"**
5. **Posicionar rostro** dentro del círculo guía
6. **Tomar foto**
7. **Confirmar registro**

✅ **¡Primera persona registrada!**

### Paso 2: Identificar Persona

1. **Ir al tab "Identificación Avanzada"**
2. **Hacer clic en el botón de cámara**
3. **Capturar foto** de la persona registrada
4. **Ver resultado:** Debería mostrar "Juan Pérez" con confianza > 50%

✅ **¡Sistema funcionando!**

---

## 📚 Funcionalidades Detalladas

### 1. Registro de Personas

#### Datos Requeridos

| Campo | Reglas | Ejemplo |
|-------|--------|---------|
| **Nombre** | 2-100 caracteres, solo letras | Juan Pérez García |
| **Documento** | 5-20 caracteres, alfanumérico, único | DNI12345678 |

#### Proceso de Captura

1. **Posicionamiento:**
   - Rostro frontal centrado
   - Buena iluminación (evitar sombras)
   - Fondo uniforme preferible
   - Sin lentes de sol ni gorros

2. **Indicadores visuales:**
   - 🟢 Verde: Posición correcta
   - 🔴 Rojo: Ajustar posición

3. **Confirmación:**
   - Preview de foto capturada
   - Embedding generado: 512D
   - Opción de rehacer si no satisface

#### Mejores Prácticas

✅ **Hacer:**
- Iluminación uniforme
- Rostro frontal completo
- Expresión neutra
- Alta resolución

❌ **Evitar:**
- Sombras fuertes
- Perfil o ángulos extremos
- Movimiento (foto borrosa)
- Baja calidad de imagen

---

### 2. Gestión de Personas

#### Ver Personas Registradas

**Tab "Personas":**
- Lista con fotos y nombres
- Búsqueda en tiempo real
- Filtrar por nombre/documento

#### Acciones Disponibles

| Acción | Descripción |
|--------|-------------|
| **Ver Detalles** | Información completa, fecha de registro |
| **Eliminar** | Borrar persona (con confirmación) |
| **Buscar** | Filtrar lista por texto |

#### Límites

- **Máximo:** 1000 personas por consulta
- **Búsqueda:** Ilimitada con paginación
- **Almacenamiento:** ~1KB por persona + foto

---

### 3. Identificación 1:N

#### Modo Manual

1. **Ir a "Identificación Avanzada"**
2. **Capturar foto**
3. **Sistema compara** contra todas las personas
4. **Ver resultado:**
   - ✅ Identificado: Nombre + confianza
   - ❌ No identificado: Top candidatos

#### Configuración

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| **Threshold** | 0.50 (50%) | Mínimo para identificar |
| **Tiempo máximo** | 5 segundos | Por identificación |
| **Personas máx** | 1000 | En una búsqueda |

#### Interpretar Resultados

**Confianza > 70%:**
- ✅ Altamente probable
- Persona identificada correctamente

**Confianza 50-70%:**
- ⚠️ Probable, verificar visualmente
- Puede ser la persona correcta

**Confianza < 50%:**
- ❌ No identificado
- Persona no registrada o calidad baja

---

### 4. Historial de Eventos

#### Ver Eventos

**Tab "Eventos":**
- Lista cronológica de identificaciones
- Filtrar por persona, fecha, tipo
- Estadísticas globales

#### Tipos de Eventos

| Tipo | Descripción | Ícono |
|------|-------------|-------|
| **Identificación** | Persona reconocida | ✅ |
| **No identificado** | Desconocido | ❌ |
| **Registro** | Nueva persona | 👤 |
| **Entrada/Salida** | Control de acceso | 🚪 |

---

## 🔧 Configuración Avanzada

### Ajustar Threshold

Si hay muchos **falsos negativos** (no reconoce):
```
Reducir threshold: 0.50 → 0.40
```

Si hay muchos **falsos positivos** (reconoce incorrectamente):
```
Aumentar threshold: 0.50 → 0.65
```

### Optimizar Rendimiento

**Para mejor precisión:**
- Registrar con múltiples fotos (diferentes ángulos)
- Usar iluminación consistente
- Actualizar fotos periódicamente

**Para mayor velocidad:**
- Limitar personas registradas a < 500
- Usar threshold más alto (menos candidatos)

---

## 🐛 Solución de Problemas

### ❌ No reconoce persona registrada

**Diagnóstico:**
```bash
dart run lib/tools/biometric_diagnostic.dart
```

**Soluciones:**
1. Verificar que embeddings sean determinísticos
2. Reducir threshold a 0.40-0.45
3. Re-registrar con mejor foto
4. Verificar iluminación similar

### ❌ Reconoce persona incorrecta

**Causas posibles:**
- Personas muy similares
- Threshold muy bajo
- Foto de baja calidad

**Soluciones:**
1. Aumentar threshold a 0.60-0.65
2. Registrar con fotos más distintivas
3. Eliminar personas duplicadas

### ⚠️ Cámara no funciona

**Verificar:**
1. Permisos otorgados en configuración del sistema
2. Otra app no está usando la cámara
3. Reiniciar app

---

## 📊 Métricas y Estadísticas

### Dashboard

**Acceso:** Tab "Estadísticas" (si disponible)

**Métricas mostradas:**
- Total de personas registradas
- Identificaciones exitosas (%)
- Tiempo promedio de identificación
- Personas más identificadas
- Distribución temporal

---

## 🔐 Privacidad y Seguridad

### Datos Almacenados Localmente

✅ **Todo permanece en tu dispositivo:**
- Fotos biométricas
- Embeddings faciales
- Historial de eventos
- Base de datos SQLite

❌ **Nunca se envía a internet:**
- Sin telemetría
- Sin analytics externos
- Sin servicios cloud

### Respaldo de Datos

**Exportar base de datos:**
```
Tab "Configuración" > Exportar Datos
```

**Importar base de datos:**
```
Tab "Configuración" > Importar Datos
```

---

## 💡 Consejos de Uso

### Para Mejor Experiencia

1. **Registrar con buena calidad:**
   - Luz natural o LED uniforme
   - Cámara de alta resolución
   - Rostro limpio y despejado

2. **Mantener consistencia:**
   - Misma iluminación en registro e identificación
   - Actualizar fotos si apariencia cambia (barba, lentes)

3. **Organizar personas:**
   - Usar documentos únicos claros (DNI, código)
   - Nombres completos para búsqueda fácil
   - Eliminar duplicados

### Casos de Uso Comunes

**Control de Acceso:**
1. Registrar empleados/residentes
2. Identificar en entrada/salida
3. Generar reportes de eventos

**Gestión de Asistencia:**
1. Registrar participantes
2. Marcar asistencia con identificación
3. Exportar estadísticas

---

## 📞 Soporte

### Problemas Comunes

1. **Revisar** [FAQ](./FAQ.md)
2. **Ejecutar** diagnóstico automático
3. **Consultar** logs en consola (modo debug)

### Reportar Issues

**Incluir:**
- Descripción del problema
- Pasos para reproducir
- Screenshots si es posible
- Logs de diagnóstico

---

## 📚 Recursos Adicionales

- **[Guía de Instalación](../setup/INSTALLATION.md)** - Setup inicial
- **[FAQ](./FAQ.md)** - Preguntas frecuentes
- **[Documentación Técnica](../technical/)** - Para desarrolladores

---

**Última actualización:** Octubre 2025  
**Versión:** 1.0.0
