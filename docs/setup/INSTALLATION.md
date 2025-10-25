# 📦 Guía de Instalación - SIOMA

Esta guía te ayudará a instalar y configurar SIOMA en tu sistema.

---

## 📋 Requisitos del Sistema

### Hardware Mínimo

- **RAM:** 4GB (8GB recomendado)
- **Almacenamiento:** 500MB libres
- **Cámara:** Frontal o trasera (mínimo 2MP)

### Software Requerido

| Software | Versión Mínima | Link |
|----------|----------------|------|
| **Flutter** | 3.9.2+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Dart** | 3.0+ | Incluido con Flutter |
| **Git** | 2.0+ | [git-scm.com](https://git-scm.com/downloads) |

### Plataformas Soportadas

- ✅ **Android** 5.0+ (API 21+)
- ✅ **iOS** 11.0+
- ✅ **Windows** 10/11
- ✅ **macOS** 10.14+
- ✅ **Linux** (Ubuntu 20.04+, Debian, Fedora)

---

## 🚀 Instalación Paso a Paso

### 1. Instalar Flutter

#### Windows
```powershell
# Descargar Flutter SDK
# Ir a https://flutter.dev/docs/get-started/install/windows
# Descomprimir en C:\src\flutter

# Agregar a PATH
$env:Path += ";C:\src\flutter\bin"

# Verificar instalación
flutter doctor
```

#### macOS / Linux
```bash
# Descargar Flutter
git clone https://github.com/flutter/flutter.git -b stable

# Agregar a PATH (agregar a ~/.bashrc o ~/.zshrc)
export PATH="$PATH:`pwd`/flutter/bin"

# Verificar instalación
flutter doctor
```

### 2. Clonar el Repositorio

```bash
# Clonar proyecto
git clone https://github.com/Bdavid117/sioma_app.git
cd sioma_app

# Verificar estructura
ls -la
```

### 3. Instalar Dependencias

```bash
# Obtener paquetes de Flutter
flutter pub get

# Verificar que no haya errores
flutter doctor -v
```

### 4. Configurar Dispositivo

#### Android

```bash
# Habilitar modo desarrollador en el dispositivo
# Configurar > Acerca del teléfono > Tocar 7 veces "Número de compilación"

# Habilitar depuración USB
# Opciones de desarrollador > Depuración USB

# Verificar dispositivo conectado
flutter devices

# Debería mostrar:
# Android SDK built for x86 (mobile) • emulator-5554 • android-x86
```

#### iOS (solo macOS)

```bash
# Instalar Xcode desde App Store

# Instalar herramientas de línea de comandos
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Abrir simulador
open -a Simulator

# Verificar dispositivos
flutter devices
```

#### Windows Desktop

```bash
# Habilitar desarrollo de Windows
flutter config --enable-windows-desktop

# Verificar
flutter devices
# Debería mostrar: Windows (desktop) • windows • windows-x64
```

### 5. Ejecutar la Aplicación

```bash
# Ejecutar en dispositivo/emulador conectado
flutter run

# Ejecutar en dispositivo específico
flutter run -d <device-id>

# Ejecutar en modo release (más rápido)
flutter run --release
```

---

## 🔧 Configuración Adicional

### Permisos de Cámara

La app solicitará permisos automáticamente, pero puedes verificar:

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera"/>
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>SIOMA necesita acceso a la cámara para captura biométrica</string>
```

### Base de Datos

La base de datos SQLite se crea automáticamente en:

- **Android:** `/data/data/com.example.sioma_app/databases/`
- **iOS:** `Library/Application Support/`
- **Windows:** `%APPDATA%/sioma_app/`
- **macOS:** `~/Library/Application Support/sioma_app/`
- **Linux:** `~/.local/share/sioma_app/`

---

## 🧪 Verificar Instalación

### Ejecutar Tests

```bash
# Tests unitarios
flutter test

# Tests de integración
flutter test integration_test/

# Diagnóstico biométrico
dart run lib/tools/biometric_diagnostic.dart
```

### Verificar Funcionalidad Básica

1. **Abrir app**
2. **Ir a tab "Registro"**
3. **Registrar persona de prueba**
4. **Ir a tab "Identificación"**
5. **Identificar persona registrada**

Si todo funciona correctamente: ✅ **¡Instalación exitosa!**

---

## 🐛 Solución de Problemas

### Error: "SDK version"

```bash
# Actualizar Flutter
flutter upgrade

# Limpiar caché
flutter clean
flutter pub get
```

### Error: "License not accepted"

```bash
# Android
flutter doctor --android-licenses
# Aceptar todas las licencias
```

### Error: "Camera permission denied"

- **Android:** Configuración > Apps > SIOMA > Permisos > Habilitar Cámara
- **iOS:** Configuración > SIOMA > Permitir acceso a Cámara

### Error: "Gradle build failed"

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Error: "CocoaPods not installed" (iOS)

```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
flutter run
```

---

## 📦 Compilar para Producción

### Android APK

```bash
# Compilar APK release
flutter build apk --release

# APK ubicado en:
# build/app/outputs/flutter-apk/app-release.apk

# Instalar en dispositivo
flutter install
```

### iOS App

```bash
# Compilar para App Store
flutter build ios --release

# Abrir en Xcode para firma y distribución
open ios/Runner.xcworkspace
```

### Windows Ejecutable

```bash
# Compilar para Windows
flutter build windows --release

# Ejecutable ubicado en:
# build/windows/x64/runner/Release/
```

---

## 🔄 Actualizar la Aplicación

```bash
# Obtener últimos cambios
git pull origin main

# Actualizar dependencias
flutter pub get

# Limpiar build anterior
flutter clean

# Ejecutar nueva versión
flutter run
```

---

## 📞 Soporte

Si encuentras problemas durante la instalación:

1. **Revisar** `flutter doctor -v`
2. **Buscar error** en documentación de Flutter
3. **Reportar issue** en GitHub con logs completos

---

**Siguiente paso:** [Guía de Usuario](../user/USER_GUIDE.md)

**Última actualización:** Octubre 2025
