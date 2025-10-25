# 🚀 Nuevas Funcionalidades - SIOMA v2.0

## 📋 Resumen

Este documento detalla las **6 nuevas funcionalidades principales** implementadas para mejorar la experiencia del usuario, optimizar el rendimiento y agregar utilidades avanzadas de análisis:

1. 🤖 **ML Kit Face Detection** - Detección facial mejorada con Google ML Kit
2. 👁️ **Liveness Detection** - Anti-spoofing con detección de parpadeo y movimiento
3. 📱 **Realtime Scanner** - Scanner continuo optimizado con throttling
4. 💾 **Database Backup/Restore** - Exportación e importación de datos en JSON
5. 📄 **PDF Report Generator** - Generación de reportes profesionales
6. 📊 **Analytics Dashboard** - Tablero de análisis con gráficas interactivas

---

## 🤖 1. ML Kit Face Detection

### 📖 Descripción
Servicio de detección facial profesional utilizando **Google ML Kit** que reemplaza el sistema básico de TensorFlow. Proporciona análisis de calidad en tiempo real con landmarks, clasificación de ojos/sonrisa y scoring de calidad.

### ✨ Características
- ✅ Detección facial real con landmarks (ojos, nariz, boca, orejas)
- ✅ Clasificación de ojos abiertos/cerrados
- ✅ Detección de sonrisa
- ✅ Análisis de calidad multi-factor:
  - Centrado del rostro (30% peso)
  - Ángulo de rotación (25% peso)
  - Ojos abiertos (25% peso)
  - Tamaño del rostro (20% peso)
- ✅ Score de calidad 0-100%
- ✅ Recomendaciones automáticas para mejorar captura

### 🔧 Uso Básico

```dart
import 'package:sioma_app/services/face_detection_service.dart';

// Obtener el servicio desde el provider
final faceDetectionService = ref.read(faceDetectionServiceProvider);

// Analizar una imagen
final result = await faceDetectionService.detectFaces('/path/to/image.jpg');

if (result.success && result.hasOneFace) {
  print('✅ Rostro detectado con calidad: ${result.analysis?.qualityScore}');
  print('📌 Score: ${(result.analysis!.qualityScore * 100).toInt()}%');
  
  // Verificar si es alta calidad
  if (result.isHighQuality) {
    print('🎯 Excelente calidad, proceder con identificación');
  } else {
    // Mostrar recomendaciones
    print('⚠️ Recomendaciones:');
    for (var recommendation in result.recommendations) {
      print('  - $recommendation');
    }
  }
} else {
  print('❌ Error: ${result.errorMessage}');
}
```

### 📊 Resultado de Análisis

```dart
class FaceQualityAnalysis {
  final bool isCentered;        // ¿Está centrado?
  final bool isProperAngle;     // ¿Ángulo correcto?
  final bool areEyesOpen;       // ¿Ojos abiertos?
  final bool isProperSize;      // ¿Tamaño adecuado?
  final double qualityScore;    // Score 0.0-1.0
  final double centerScore;     // Sub-score centrado
  final double angleScore;      // Sub-score ángulo
  final double eyeScore;        // Sub-score ojos
  final double sizeScore;       // Sub-score tamaño
}
```

### 🎯 Casos de Uso
- **Captura de foto de registro**: Validar calidad antes de guardar
- **Identificación en tiempo real**: Pre-filtrar imágenes de baja calidad
- **Control de acceso**: Asegurar detecciones confiables

---

## 👁️ 2. Liveness Detection (Anti-Spoofing)

### 📖 Descripción
Sistema de **detección de vida** que previene ataques con fotos impresas, pantallas o máscaras. Utiliza análisis de parpadeo y detección de movimiento entre frames para verificar que se trata de una persona real.

### ✨ Características
- ✅ Detección de parpadeo (blink detection)
  - Análisis de ratio de ojos (EAR - Eye Aspect Ratio)
  - Detección de secuencia: abierto → cerrado → abierto
  - Timeout configurable (5 segundos por defecto)
- ✅ Detección de movimiento
  - Análisis de desplazamiento de landmarks
  - Verificación de movimiento significativo entre frames
  - Umbral de 15 píxeles de movimiento
- ✅ Modo combinado (blink + movement)
  - Máxima seguridad con doble verificación
  - Recomendado para accesos críticos

### 🔧 Uso Básico

#### Detección por Parpadeo

```dart
import 'package:sioma_app/services/liveness_detector.dart';

final livenessDetector = ref.read(livenessDetectorProvider);

// Iniciar detección
livenessDetector.startBlinkDetection();

// Procesar frames de video en loop
while (capturing) {
  final imagePath = await captureFrame();
  final result = await livenessDetector.checkLivenessByBlink(imagePath);
  
  if (result.isLive) {
    print('✅ Persona real detectada!');
    print('⏱️ Tiempo: ${result.timeElapsed.toStringAsFixed(1)}s');
    print('👁️ Parpadeos detectados: ${result.blinkCount}');
    break;
  } else if (result.timedOut) {
    print('⏱️ Timeout: El usuario no parpadeó a tiempo');
    break;
  } else {
    // Mostrar feedback al usuario
    print('👁️ ${result.message}');
  }
}

// Limpiar al finalizar
livenessDetector.reset();
```

#### Detección por Movimiento

```dart
// Capturar 2 frames con separación de ~1 segundo
final frame1 = await captureFrame();
await Future.delayed(Duration(milliseconds: 1000));
final frame2 = await captureFrame();

final result = await livenessDetector.checkLivenessByMovement(frame1, frame2);

if (result.isLive) {
  print('✅ Movimiento real detectado!');
  print('📏 Distancia promedio: ${result.averageDistance?.toStringAsFixed(1)} px');
}
```

#### Modo Combinado (Máxima Seguridad)

```dart
livenessDetector.startBlinkDetection();

final frame1 = await captureFrame();
final blinkResult = await livenessDetector.checkLivenessByBlink(frame1);

if (blinkResult.isLive) {
  // Verificar también movimiento
  await Future.delayed(Duration(milliseconds: 1000));
  final frame2 = await captureFrame();
  final moveResult = await livenessDetector.checkLivenessByMovement(frame1, frame2);
  
  if (moveResult.isLive) {
    print('🔒 Verificación completa: Persona real confirmada');
  }
}
```

### 🎯 Casos de Uso
- **Registro de nuevos usuarios**: Verificar que no se use una foto
- **Acceso a zonas restringidas**: Prevenir spoofing con impresiones
- **Autenticación crítica**: Pagos, acceso a datos sensibles

---

## 📱 3. Realtime Scanner Service

### 📖 Descripción
Servicio de **scanner continuo optimizado** para identificación en tiempo real. Procesa frames de video con throttling inteligente, cooldown entre identificaciones y estadísticas detalladas de rendimiento.

### ✨ Características
- ✅ Procesamiento continuo de frames con throttling (cada 2s)
- ✅ Cooldown entre identificaciones (5s) para evitar duplicados
- ✅ Validación de calidad previa a identificación
- ✅ Estadísticas en tiempo real:
  - Frames procesados
  - Rostros detectados
  - Identificaciones exitosas
  - Promedio de confianza
- ✅ Callbacks para feedback visual inmediato

### 🔧 Uso Básico

```dart
import 'package:sioma_app/services/realtime_scanner_service.dart';

final scannerService = ref.read(realtimeScannerServiceProvider);

// Configurar callback para resultados
void handleScanResult(ScanResult result) {
  switch (result.status) {
    case ScanStatus.identified:
      print('✅ Identificado: ${result.personName}');
      print('📊 Confianza: ${(result.confidence! * 100).toStringAsFixed(1)}%');
      // Mostrar UI de éxito
      showSuccessDialog(result.personName!);
      break;
      
    case ScanStatus.notRegistered:
      print('⚠️ Persona no registrada');
      // Mostrar opción de registro
      showRegisterDialog();
      break;
      
    case ScanStatus.lowQuality:
      print('📸 Mejora la calidad: ${result.message}');
      // Mostrar feedback visual
      showQualityFeedback(result.message);
      break;
      
    case ScanStatus.processing:
      print('⏳ Procesando...');
      break;
      
    case ScanStatus.error:
      print('❌ Error: ${result.message}');
      break;
  }
}

// Iniciar scanner
scannerService.startScanning(onResult: handleScanResult);

// En el loop de la cámara, enviar frames
while (scanning) {
  final imagePath = await captureFrameToFile();
  await scannerService.processFrame(imagePath);
  await Future.delayed(Duration(milliseconds: 100)); // 10 FPS
}

// Detener scanner
scannerService.stopScanning();

// Ver estadísticas
final stats = scannerService.getStatistics();
print('📊 Estadísticas:');
print('  Frames: ${stats.framesProcessed}');
print('  Rostros: ${stats.facesDetected}');
print('  Identificaciones: ${stats.identificationCount}');
print('  Confianza promedio: ${(stats.averageConfidence * 100).toStringAsFixed(1)}%');
```

### 📊 Estados del Scanner

```dart
enum ScanStatus {
  idle,              // Esperando
  processing,        // Procesando frame
  identified,        // Persona identificada
  notRegistered,     // Rostro detectado pero no en BD
  lowQuality,        // Calidad insuficiente
  cooldown,          // En cooldown (evitar duplicados)
  error,             // Error de procesamiento
}
```

### 🎯 Casos de Uso
- **Control de acceso continuo**: Puertas automáticas
- **Monitoreo de zona**: Alertas en tiempo real
- **Eventos masivos**: Identificación rápida en multitudes

---

## 💾 4. Database Backup & Restore

### 📖 Descripción
Sistema completo de **exportación e importación de datos** en formato JSON. Permite hacer respaldos de toda la base de datos (personas, eventos, análisis) y restaurarlos en otro dispositivo o después de reinstalar la app.

### ✨ Características
- ✅ Exportación a JSON estructurado
- ✅ Backup completo:
  - Personas registradas (con embeddings)
  - Eventos de identificación
  - Eventos de análisis
  - Eventos personalizados
- ✅ Validación de estructura antes de importar
- ✅ Reporte de resultados (registros importados)
- ✅ Gestión automática de archivos temporales
- ✅ Opción de compartir backup (share_plus)

### 🔧 Uso Básico

#### Exportar Base de Datos

```dart
import 'package:sioma_app/services/database_backup_service.dart';

final backupService = ref.read(databaseBackupServiceProvider);

// Crear backup
try {
  final backupFile = await backupService.exportDatabase();
  
  print('✅ Backup creado exitosamente!');
  print('📂 Ubicación: ${backupFile.path}');
  print('📦 Tamaño: ${(backupFile.lengthSync() / 1024).toStringAsFixed(1)} KB');
  
  // Opción 1: Compartir el backup
  await backupService.shareBackup(backupFile);
  
  // Opción 2: Mover a ubicación permanente
  final downloadsDir = await getExternalStorageDirectory();
  await backupFile.copy('${downloadsDir!.path}/sioma_backup.json');
  
} catch (e) {
  print('❌ Error al crear backup: $e');
}
```

#### Importar Base de Datos

```dart
// Seleccionar archivo (usar file_picker)
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json'],
);

if (result != null) {
  final backupPath = result.files.single.path!;
  
  // Importar datos
  try {
    final importResult = await backupService.importDatabase(backupPath);
    
    print('✅ Importación completada!');
    print('👥 Personas: ${importResult.personsImported}');
    print('📅 Eventos: ${importResult.eventsImported}');
    print('📊 Análisis: ${importResult.analysisImported}');
    print('⭐ Eventos custom: ${importResult.customEventsImported}');
    
    // Mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Importación Exitosa'),
        content: Text('Se importaron ${importResult.totalImported} registros'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
    
  } catch (e) {
    print('❌ Error al importar: $e');
  }
}
```

#### Validar Backup antes de Importar

```dart
final validation = await backupService.validateBackup('/path/to/backup.json');

if (validation.isValid) {
  print('✅ Backup válido, proceder con importación');
} else {
  print('❌ Backup corrupto: ${validation.message}');
}
```

### 📊 Formato JSON del Backup

```json
{
  "version": "1.0",
  "exportDate": "2025-10-24T10:30:00.000",
  "persons": [
    {
      "id": 1,
      "name": "Juan Pérez",
      "documentId": "12345678",
      "embedding": "0.123,0.456,0.789,...",
      "photoPath": "/data/.../photo.jpg",
      "createdAt": "2025-10-20T08:00:00.000"
    }
  ],
  "events": [...],
  "analysisEvents": [...],
  "customEvents": [...]
}
```

### 🎯 Casos de Uso
- **Migración de dispositivos**: Transferir datos a nuevo celular
- **Backup periódico**: Respaldos automáticos semanales
- **Testing**: Cargar datos de prueba rápidamente
- **Recuperación**: Restaurar después de reinstalar app

---

## 📄 5. PDF Report Generator

### 📖 Descripción
Generador de **reportes profesionales en PDF** con estadísticas de asistencia, gráficos y tablas detalladas. Utiliza la librería `pdf` para crear documentos con diseño corporativo.

### ✨ Características
- ✅ Encabezado con período y fecha de generación
- ✅ Tarjetas de estadísticas clave (cards):
  - Total de eventos
  - Personas únicas identificadas
  - Promedio de confianza
- ✅ Tabla de eventos (últimos 50):
  - Fecha/Hora
  - Nombre
  - Documento
  - Tipo de evento
  - Confianza
- ✅ Diseño profesional con colores corporativos
- ✅ Vista previa antes de compartir
- ✅ Exportación y compartir (email, WhatsApp, etc.)

### 🔧 Uso Básico

#### Generar Reporte de Período

```dart
import 'package:sioma_app/services/pdf_report_generator.dart';

final pdfGenerator = ref.read(pdfReportGeneratorProvider);

// Definir período
final startDate = DateTime.now().subtract(Duration(days: 30));
final endDate = DateTime.now();

try {
  final pdfFile = await pdfGenerator.generateAttendanceReport(
    startDate,
    endDate,
  );
  
  print('✅ Reporte generado!');
  print('📄 ${pdfFile.path}');
  print('📦 ${(pdfFile.lengthSync() / 1024).toStringAsFixed(1)} KB');
  
  // Opción 1: Vista previa
  await pdfGenerator.previewPDF(pdfFile);
  
  // Opción 2: Compartir directamente
  await pdfGenerator.sharePDF(pdfFile);
  
} catch (e) {
  print('❌ Error al generar PDF: $e');
}
```

#### Generar Reporte Mensual Automático

```dart
Future<void> generateMonthlyReport() async {
  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, 1);
  final lastDay = DateTime(now.year, now.month + 1, 0);
  
  final pdfFile = await pdfGenerator.generateAttendanceReport(
    firstDay,
    lastDay,
  );
  
  // Guardar en carpeta de documentos
  final appDocDir = await getApplicationDocumentsDirectory();
  final monthlyReportsDir = Directory('${appDocDir.path}/monthly_reports');
  await monthlyReportsDir.create(recursive: true);
  
  final fileName = 'reporte_${now.year}_${now.month.toString().padLeft(2, '0')}.pdf';
  await pdfFile.copy('${monthlyReportsDir.path}/$fileName');
  
  print('📅 Reporte mensual guardado: $fileName');
}
```

#### Enviar Reporte por Email

```dart
import 'package:share_plus/share_plus.dart';

final pdfFile = await pdfGenerator.generateAttendanceReport(start, end);

// Compartir con subject y texto
await Share.shareXFiles(
  [XFile(pdfFile.path)],
  subject: 'Reporte de Asistencia - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
  text: 'Adjunto el reporte de asistencia del período solicitado.',
);
```

### 📊 Contenido del Reporte

```
┌─────────────────────────────────────────┐
│   REPORTE DE ASISTENCIA                 │
│   Período: 01/10/2025 - 31/10/2025     │
│   Generado: 24/10/2025 10:30           │
└─────────────────────────────────────────┘

┌──────────┐ ┌──────────┐ ┌──────────┐
│ 1,234    │ │   156    │ │  94.5%   │
│ Eventos  │ │ Personas │ │ Confianza│
└──────────┘ └──────────┘ └──────────┘

┌─────────────────────────────────────────┐
│ EVENTOS (Últimos 50)                    │
├──────┬──────────┬─────────┬──────┬─────┤
│Fecha │ Nombre   │ Doc     │ Tipo │Conf.│
├──────┼──────────┼─────────┼──────┼─────┤
│10:30 │Juan Pérez│12345678 │Entry │ 95% │
│10:31 │Ana García│87654321 │Entry │ 92% │
│...   │...       │...      │...   │...  │
└──────┴──────────┴─────────┴──────┴─────┘
```

### 🎯 Casos de Uso
- **Reportes mensuales**: Envío automático a RRHH
- **Auditoría**: Evidencia de asistencia para nómina
- **Análisis**: Revisión de patrones de entrada/salida
- **Compliance**: Cumplimiento normativo con registros físicos

---

## 📊 6. Analytics Dashboard

### 📖 Descripción
**Tablero de análisis visual** con gráficas interactivas usando `fl_chart`. Muestra estadísticas clave, tendencias temporales, Top 5 personas más identificadas y distribución de confianza.

### ✨ Características
- ✅ Tarjetas de estadísticas (Cards):
  - Total eventos
  - Personas únicas
  - Promedio de confianza
  - Eventos hoy
- ✅ Gráfica de barras: Eventos por día (últimos 7 días)
- ✅ Gráfica de líneas: Tendencia de confianza (últimos 30 días)
- ✅ Top 5 personas más identificadas
- ✅ Distribución de niveles de confianza (ranges)
- ✅ Actualización automática cada 30 segundos
- ✅ Pull-to-refresh manual

### 🔧 Uso Básico

#### Navegar al Dashboard

```dart
import 'package:sioma_app/screens/analytics_dashboard_screen.dart';

// Desde cualquier parte de la app
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AnalyticsDashboardScreen(),
  ),
);
```

#### Dashboard en la Pantalla Principal

```dart
// Agregar botón en HomeScreen
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsDashboardScreen(),
      ),
    );
  },
  child: Icon(Icons.analytics),
  tooltip: 'Ver Analytics',
)
```

#### Integrar Gráfica Específica

```dart
import 'package:sioma_app/screens/analytics_dashboard_screen.dart';

// Usar solo la gráfica de barras en otra pantalla
class CustomStatsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DashboardData>(
      future: DashboardData.loadFromDatabase(ref.read(databaseServiceProvider)),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _buildEventsBarChart(snapshot.data!);
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

### 📊 Tipos de Gráficas

#### 1. Gráfica de Barras (Eventos por Día)
```dart
// Muestra eventos de los últimos 7 días
Map<String, int> eventsPerDay = {
  'Lun': 45,
  'Mar': 52,
  'Mié': 38,
  'Jue': 61,
  'Vie': 48,
  'Sáb': 12,
  'Dom': 8,
};
```

#### 2. Gráfica de Líneas (Tendencia de Confianza)
```dart
// Promedio de confianza por día (últimos 30 días)
List<FlSpot> confidenceTrend = [
  FlSpot(0, 0.92),
  FlSpot(1, 0.94),
  FlSpot(2, 0.91),
  // ...
];
```

#### 3. Top 5 Personas
```dart
List<TopPerson> topPersons = [
  TopPerson(name: 'Juan Pérez', count: 156),
  TopPerson(name: 'Ana García', count: 142),
  TopPerson(name: 'Carlos López', count: 128),
  TopPerson(name: 'María Rodríguez', count: 115),
  TopPerson(name: 'Pedro Sánchez', count: 98),
];
```

#### 4. Distribución de Confianza
```dart
Map<String, int> confidenceDistribution = {
  '90-100%': 1234,  // Excelente
  '80-89%': 456,    // Bueno
  '70-79%': 123,    // Aceptable
  '< 70%': 45,      // Bajo
};
```

### 🎯 Casos de Uso
- **Monitoreo gerencial**: Métricas en tiempo real para supervisores
- **Optimización**: Identificar horarios pico y ajustar recursos
- **Calidad**: Detectar problemas de confianza y mejorar captura
- **Reportes ejecutivos**: Screenshots para presentaciones

---

## 🔗 Integración de Todas las Features

### Ejemplo: Pantalla de Captura Completa

```dart
class SmartCaptureScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<SmartCaptureScreen> createState() => _SmartCaptureScreenState();
}

class _SmartCaptureScreenState extends ConsumerState<SmartCaptureScreen> {
  late FaceDetectionService _faceDetection;
  late LivenessDetector _liveness;
  late RealtimeScannerService _scanner;
  
  @override
  void initState() {
    super.initState();
    _faceDetection = ref.read(faceDetectionServiceProvider);
    _liveness = ref.read(livenessDetectorProvider);
    _scanner = ref.read(realtimeScannerServiceProvider);
    
    // Iniciar scanner con liveness
    _startSmartCapture();
  }
  
  Future<void> _startSmartCapture() async {
    // 1. Iniciar detección de liveness
    _liveness.startBlinkDetection();
    
    // 2. Configurar scanner
    _scanner.startScanning(onResult: (result) async {
      if (result.status == ScanStatus.identified) {
        // 3. Verificar liveness antes de confirmar
        final frame = await _captureCurrentFrame();
        final livenessResult = await _liveness.checkLivenessByBlink(frame);
        
        if (livenessResult.isLive) {
          // 4. Verificar calidad con ML Kit
          final qualityResult = await _faceDetection.detectFaces(frame);
          
          if (qualityResult.isHighQuality) {
            // 5. TODO: Éxito completo
            _showSuccessDialog(result);
          } else {
            _showQualityWarning(qualityResult.recommendations);
          }
        } else {
          _showLivenessWarning();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _scanner.stopScanning();
    _liveness.reset();
    super.dispose();
  }
}
```

---

## 📚 Dependencias Agregadas

```yaml
dependencies:
  # ML Kit Face Detection
  google_mlkit_face_detection: ^0.10.1
  
  # PDF Generation
  pdf: ^3.11.3
  printing: ^5.14.2
  
  # Sharing & File Handling
  share_plus: ^7.2.2
  
  # Charts & Analytics
  fl_chart: ^0.66.2
  
  # Image Processing (upgraded)
  image: ^4.5.4
```

---

## 🎓 Mejores Prácticas

### 1. Performance
- ✅ Usar throttling en scanner (no procesar cada frame)
- ✅ Implementar cooldown entre identificaciones
- ✅ Liberar recursos al salir de pantallas (dispose)

### 2. UX
- ✅ Mostrar feedback visual inmediato
- ✅ Usar loading indicators durante procesamiento
- ✅ Proveer recomendaciones cuando falla calidad

### 3. Seguridad
- ✅ Siempre validar liveness en accesos críticos
- ✅ Usar modo combinado (blink + movement) para máxima seguridad
- ✅ Validar backups antes de importar

### 4. Mantenimiento
- ✅ Generar reportes PDF periódicamente
- ✅ Hacer backups automáticos semanales
- ✅ Monitorear analytics para detectar anomalías

---

## 🐛 Troubleshooting

### ML Kit no detecta rostros
**Problema**: `FaceDetectionResult` retorna `success: false`
**Soluciones**:
- Verificar iluminación (no muy oscura ni muy brillante)
- Asegurar que el rostro ocupe al menos 40% del frame
- Verificar permisos de cámara

### Liveness siempre falla
**Problema**: `LivenessResult.isLive` siempre es `false`
**Soluciones**:
- Aumentar timeout (default 5s → 10s)
- Verificar que ML Kit esté detectando los ojos
- Usar modo de solo movimiento si hay problemas con parpadeo

### Scanner muy lento
**Problema**: Procesamiento toma > 5 segundos
**Soluciones**:
- Aumentar throttle interval (2s → 3s)
- Reducir resolución de cámara
- Verificar que no se procesen frames en paralelo

### PDF sin datos
**Problema**: Reporte generado está vacío
**Soluciones**:
- Verificar que hay eventos en el período seleccionado
- Revisar logs de `AppLogger`
- Verificar permisos de escritura en storage

### Analytics no actualiza
**Problema**: Gráficas muestran datos antiguos
**Soluciones**:
- Hacer pull-to-refresh
- Verificar que auto-refresh esté habilitado
- Revisar que `DatabaseService` esté retornando datos correctos

---

## 📖 Referencias

- [Google ML Kit Documentation](https://developers.google.com/ml-kit)
- [pdf Package Documentation](https://pub.dev/packages/pdf)
- [fl_chart Examples](https://pub.dev/packages/fl_chart)
- [share_plus Plugin](https://pub.dev/packages/share_plus)

---

## 🎉 Conclusión

Estas **6 nuevas funcionalidades** transforman SIOMA en una solución empresarial completa:

✅ **Mejor detección** con Google ML Kit  
✅ **Mayor seguridad** con liveness detection  
✅ **Identificación continua** con realtime scanner  
✅ **Portabilidad de datos** con backup/restore  
✅ **Reportes profesionales** con PDF generator  
✅ **Insights accionables** con analytics dashboard  

Para más información, consulta la documentación completa en `/docs`.
