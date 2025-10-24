# 📘 FASE 2: CAPTURA DE CÁMARA Y GESTIÓN DE ARCHIVOS

## ✅ Estado: COMPLETADO

## 📦 Dependencias Instaladas
```yaml
camera: ^0.10.0
path_provider: ^2.1.4
permission_handler: ^11.3.1
image: ^3.0.2
```

## 📁 Archivos Implementados

### 1. `lib/services/camera_service.dart`
- **Patrón:** Singleton con gestión de recursos
- **Funcionalidades:**
  - Inicialización automática con permisos
  - Cambio entre cámara frontal/trasera
  - Captura segura con validación de archivos
  - Organización en directorio `/faces/`
  - Limpieza automática (límite 1000 archivos)
  - Generación de nombres únicos seguros

### 2. `lib/screens/camera_capture_screen.dart`
- **Interfaz profesional de captura:**
  - Preview en tiempo real
  - Guías visuales (marco oval + esquinas verdes)
  - Información de persona en pantalla
  - Controles intuitivos (capturar/cambiar/cerrar)
  - Preview de confirmación

### 3. `lib/screens/camera_test_screen.dart`
- **Galería de gestión:**
  - Grid 2x2 de fotos capturadas
  - Estadísticas en tiempo real
  - Detalles de archivos (tamaño, fecha)
  - Eliminación individual/masiva

## 🔒 Configuración de Permisos

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Esta aplicación necesita acceso a la cámara para capturar fotos de rostro.</string>
```

## 🛡️ Seguridad Implementada
- ✅ Validación de nombres de archivo (previene path traversal)
- ✅ Límites de tamaño: 1KB - 10MB
- ✅ Extensiones permitidas: .jpg únicamente
- ✅ Sanitización automática de nombres
- ✅ Gestión segura de memoria
