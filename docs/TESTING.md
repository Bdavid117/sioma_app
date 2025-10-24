# 🧪 CÓDIGOS PARA PROBAR EL PROGRAMA SIOMA

## 📋 COMANDOS DE INSTALACIÓN Y CONFIGURACIÓN

### 1. **Preparar el Proyecto**
```bash
# Navegar al directorio del proyecto
cd C:\Users\BrayanDavidCollazosE\StudioProjects\sioma_app

# Limpiar proyecto
flutter clean

# Instalar dependencias
flutter pub get

# Verificar configuración
flutter doctor
```

### 2. **Ejecutar en Dispositivo**
```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en dispositivo específico (reemplaza con tu ID)
flutter run -d 24094RAD4G

# O ejecutar en cualquier dispositivo disponible
flutter run
```

## 🎯 PRUEBAS POR PESTAÑA

### **PESTAÑA 1: REGISTRO** (Principal)

#### **Prueba A: Registro Completo Exitoso**
```
1. Abre la app → Ve a "Registro"
2. Completa formulario:
   - Nombre: "Juan Carlos Pérez"
   - Documento: "12345678"
3. Presiona "Continuar" → Debe validar y avanzar
4. Presiona "Capturar Foto" → Se abre cámara
5. Coloca rostro en marco → Presiona círculo blanco
6. Confirma foto → "Usar Esta Foto"
7. Espera procesamiento → Ver "Características biométricas generadas"
8. Confirma registro → "Confirmar y Guardar"
9. Ve mensaje éxito → Auto-reset en 3 segundos

✅ Resultado esperado: Persona registrada exitosamente
```

#### **Prueba B: Validaciones de Formulario**
```
1. Intenta nombres inválidos:
   - "" (vacío) → Error
   - "A" (muy corto) → Error
   - "123" (números) → Error
   - "Juan@#" (caracteres especiales) → Error

2. Intenta documentos inválidos:
   - "" (vacío) → Error
   - "123" (muy corto) → Error
   - "ABCD@#$%" (caracteres especiales) → Error

3. Intenta documento duplicado:
   - Usa mismo documento → "Ya existe una persona registrada"

✅ Resultado esperado: Validaciones funcionando correctamente
```

### **PESTAÑA 2: PERSONAS** (Gestión)

#### **Prueba C: Gestión de Personas**
```
1. Ve a "Personas" → Lista de personas registradas
2. Busca persona:
   - Escribe "Juan" → Filtra resultados
   - Escribe "12345" → Filtra por documento
3. Toca una persona → Ve detalles completos
4. Usa menú ⋮ → "Ver detalles" → Info completa
5. Elimina persona:
   - Menú ⋮ → "Eliminar"
   - Confirma → Persona eliminada

✅ Resultado esperado: Gestión completa funcional
```

### **PESTAÑA 3: BASE DE DATOS** (Pruebas técnicas)

#### **Prueba D: Operaciones de BD**
```
1. Ve a "Base de Datos"
2. Agrega persona de prueba:
   - Nombre: "María Test"
   - Documento: "TEST001"
   - Presiona "Agregar"
3. Ve contador actualizado
4. Elimina persona → Botón rojo
5. Usa "Eliminar BD" → Limpia todo

✅ Resultado esperado: CRUD básico funcional
```

### **PESTAÑA 4: CÁMARA** (Pruebas técnicas)

#### **Prueba E: Sistema de Cámara**
```
1. Ve a "Cámara" → Galería vacía inicialmente
2. Presiona "Capturar Foto" → Se abre cámara
3. Prueba cambiar cámara → Botón switch
4. Captura varias fotos → Aparecen en galería
5. Toca foto → Ve detalles (tamaño, fecha)
6. Elimina foto → Confirmación

✅ Resultado esperado: Sistema de archivos funcional
```

### **PESTAÑA 5: EMBEDDINGS** (Pruebas técnicas)

#### **Prueba F: Procesamiento IA**
```
1. Ve a "Embeddings"
2. Captura imagen → "Capturar Imagen"
3. Genera embedding → Botón cerebro
4. Ve detalles → Botón "i" → Dimensiones y valores
5. Genera varios embeddings
6. Compara similitudes → Menú ⋮ → "Comparar Embeddings"

✅ Resultado esperado: Embeddings y similitudes calculadas
```

## 🔍 PRUEBAS DE INTEGRACIÓN COMPLETA

### **Prueba G: Flujo Completo End-to-End**
```
1. REGISTRO:
   - Registra "Ana García" - "87654321"
   - Registra "Carlos López" - "11111111"
   - Registra "María Rodríguez" - "22222222"

2. GESTIÓN:
   - Ve a "Personas" → 3 personas listadas
   - Busca "Ana" → Solo Ana visible
   - Ve detalles de cada una

3. EMBEDDINGS:
   - Ve a "Embeddings" → 3+ imágenes disponibles
   - Genera embeddings para todas
   - Compara similitudes → Ve porcentajes

4. LIMPIEZA:
   - Elimina una persona desde "Personas"
   - Verifica que desaparece de toda la app

✅ Resultado esperado: Sistema integrado funcionando
```

## 🚨 PRUEBAS DE SEGURIDAD

### **Prueba H: Validaciones de Seguridad**
```
1. INYECCIÓN SQL:
   - Documento: "'; DROP TABLE persons; --"
   - Nombre: "<script>alert('hack')</script>"
   → Debe ser sanitizado/rechazado

2. PATH TRAVERSAL:
   - Intenta capturar imagen con nombre: "../../../etc/passwd"
   → Debe ser sanitizado

3. ARCHIVOS GRANDES:
   - Captura muchas imágenes (50+)
   → Debe limpiar automáticamente

✅ Resultado esperado: Sistema seguro y robusto
```

## 📊 MÉTRICAS DE ÉXITO

### **Criterios de Aceptación:**
- [ ] App inicia sin errores
- [ ] Todas las 5 pestañas funcionan
- [ ] Registro completo exitoso
- [ ] Fotos se capturan y guardan
- [ ] Embeddings se generan correctamente
- [ ] Búsquedas y filtros funcionan
- [ ] Eliminaciones con confirmación
- [ ] Validaciones previenen datos inválidos
- [ ] No crashes durante uso normal

### **Performance:**
- Tiempo de carga: < 3 segundos
- Captura de foto: < 2 segundos
- Generación embedding: < 5 segundos
- Búsquedas: Instantáneas

---

## 🆘 TROUBLESHOOTING

### **Errores Comunes:**
1. **"Target of URI doesn't exist"** → `flutter pub get`
2. **"Namespace not specified"** → Versiones ya corregidas
3. **"Camera permission denied"** → Permitir en configuración
4. **App muy lenta** → Reiniciar dispositivo

### **Reset Completo:**
```bash
flutter clean
flutter pub get
flutter run
```
