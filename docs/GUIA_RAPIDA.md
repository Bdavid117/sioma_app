# 📘 Guía Rápida de Uso - SIOMA v2.0

Esta guía proporciona ejemplos de código **copy-paste** listos para usar con las nuevas funcionalidades.

---

## 🔌 Configuración Inicial

### 1. Importar Providers

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sioma_app/providers/service_providers.dart';
```

### 2. Usar en Widget

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Acceder a servicios
    final faceDetection = ref.read(faceDetectionServiceProvider);
    final liveness = ref.read(livenessDetectorProvider);
    final scanner = ref.read(realtimeScannerServiceProvider);
    final backup = ref.read(databaseBackupServiceProvider);
    final pdfGen = ref.read(pdfReportGeneratorProvider);
    
    // Tu UI aquí
  }
}
```

---

## 🤖 ML Kit Face Detection - Snippets

### Validar Calidad de Foto

```dart
Future<bool> validatePhotoQuality(String imagePath) async {
  final faceDetection = ref.read(faceDetectionServiceProvider);
  final result = await faceDetection.detectFaces(imagePath);
  
  if (!result.success) {
    showSnackBar('Error: ${result.errorMessage}');
    return false;
  }
  
  if (!result.hasOneFace) {
    showSnackBar('Por favor, asegura que solo haya un rostro en la imagen');
    return false;
  }
  
  if (!result.isHighQuality) {
    // Mostrar recomendaciones
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️ Mejora la calidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: result.recommendations.map((r) => 
            ListTile(leading: Icon(Icons.info), title: Text(r))
          ).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
    return false;
  }
  
  return true; // ✅ Todo bien!
}
```

### Widget de Feedback de Calidad

```dart
class QualityIndicator extends StatelessWidget {
  final FaceQualityAnalysis analysis;
  
  @override
  Widget build(BuildContext context) {
    final score = (analysis.qualityScore * 100).toInt();
    final color = score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircularProgressIndicator(
              value: analysis.qualityScore,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(color),
            ),
            SizedBox(height: 8),
            Text('$score%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric('Centrado', analysis.isCentered),
                _buildMetric('Ángulo', analysis.isProperAngle),
                _buildMetric('Ojos', analysis.areEyesOpen),
                _buildMetric('Tamaño', analysis.isProperSize),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetric(String label, bool value) {
    return Column(
      children: [
        Icon(value ? Icons.check_circle : Icons.cancel, 
             color: value ? Colors.green : Colors.red),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10)),
      ],
    );
  }
}
```

---

## 👁️ Liveness Detection - Snippets

### Pantalla de Verificación de Liveness (Parpadeo)

```dart
class LivenessCheckScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LivenessCheckScreen> createState() => _LivenessCheckScreenState();
}

class _LivenessCheckScreenState extends ConsumerState<LivenessCheckScreen> {
  late LivenessDetector _detector;
  String _message = 'Parpadea para verificar que eres real';
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _detector = ref.read(livenessDetectorProvider);
    _detector.startBlinkDetection();
    _startChecking();
  }
  
  Future<void> _startChecking() async {
    setState(() => _isProcessing = true);
    
    while (_isProcessing) {
      // Capturar frame (implementa según tu cámara)
      final imagePath = await captureFrame();
      
      final result = await _detector.checkLivenessByBlink(imagePath);
      
      setState(() => _message = result.message);
      
      if (result.isLive) {
        _showSuccess();
        break;
      } else if (result.timedOut) {
        _showTimeout();
        break;
      }
      
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
  
  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('✅ Verificación Exitosa'),
        content: Text('Se detectó que eres una persona real'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); // Retornar success
            },
            child: Text('Continuar'),
          ),
        ],
      ),
    );
  }
  
  void _showTimeout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⏱️ Tiempo Agotado'),
        content: Text('No se detectó parpadeo a tiempo. Intenta de nuevo.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false); // Retornar failure
            },
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verificación de Liveness')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_red_eye, size: 100, color: Colors.blue),
            SizedBox(height: 24),
            Text(_message, style: TextStyle(fontSize: 18)),
            SizedBox(height: 24),
            if (_isProcessing) CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _detector.reset();
    super.dispose();
  }
}
```

### Verificación Rápida antes de Registro

```dart
Future<bool> verifyLivenessBeforeRegistration(String imagePath) async {
  final detector = ref.read(livenessDetectorProvider);
  
  // Mostrar diálogo de instrucciones
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('👁️ Verificación de Liveness'),
      content: Text('Por favor, parpadea cuando veas el indicador'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Iniciar'),
        ),
      ],
    ),
  );
  
  detector.startBlinkDetection();
  final result = await detector.checkLivenessByBlink(imagePath);
  
  return result.isLive;
}
```

---

## 📱 Realtime Scanner - Snippets

### Pantalla de Scanner Continuo

```dart
class RealtimeScannerScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<RealtimeScannerScreen> createState() => _RealtimeScannerScreenState();
}

class _RealtimeScannerScreenState extends ConsumerState<RealtimeScannerScreen> {
  late RealtimeScannerService _scanner;
  String _statusMessage = 'Buscando rostros...';
  Color _statusColor = Colors.grey;
  
  @override
  void initState() {
    super.initState();
    _scanner = ref.read(realtimeScannerServiceProvider);
    _scanner.startScanning(onResult: _handleResult);
  }
  
  void _handleResult(ScanResult result) {
    setState(() {
      switch (result.status) {
        case ScanStatus.identified:
          _statusMessage = '✅ ${result.personName}';
          _statusColor = Colors.green;
          // Vibración y sonido de éxito
          HapticFeedback.mediumImpact();
          break;
          
        case ScanStatus.notRegistered:
          _statusMessage = '⚠️ Persona no registrada';
          _statusColor = Colors.orange;
          break;
          
        case ScanStatus.lowQuality:
          _statusMessage = '📸 ${result.message}';
          _statusColor = Colors.yellow;
          break;
          
        case ScanStatus.processing:
          _statusMessage = '⏳ Procesando...';
          _statusColor = Colors.blue;
          break;
          
        case ScanStatus.cooldown:
          _statusMessage = '⏸️ Espera ${result.cooldownRemaining}s';
          _statusColor = Colors.grey;
          break;
          
        case ScanStatus.error:
          _statusMessage = '❌ ${result.message}';
          _statusColor = Colors.red;
          break;
          
        default:
          _statusMessage = 'Buscando rostros...';
          _statusColor = Colors.grey;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = _scanner.getStatistics();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner en Tiempo Real'),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () => _showStats(stats),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cámara (implementa según tu solución)
          CameraPreview(cameraController),
          
          // Status Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              color: _statusColor.withOpacity(0.8),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
          
          // Stats Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.black54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Frames', '${stats.framesProcessed}'),
                  _buildStat('Rostros', '${stats.facesDetected}'),
                  _buildStat('IDs', '${stats.identificationCount}'),
                  _buildStat('Conf.', '${(stats.averageConfidence * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
  
  @override
  void dispose() {
    _scanner.stopScanning();
    super.dispose();
  }
}
```

---

## 💾 Database Backup - Snippets

### Botón de Exportar Backup

```dart
ElevatedButton.icon(
  icon: Icon(Icons.upload),
  label: Text('Exportar Backup'),
  onPressed: () async {
    final backup = ref.read(databaseBackupServiceProvider);
    
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()),
      );
      
      final file = await backup.exportDatabase();
      Navigator.pop(context); // Quitar loading
      
      // Compartir
      await backup.shareBackup(file);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Backup exportado exitosamente')),
      );
    } catch (e) {
      Navigator.pop(context); // Quitar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  },
)
```

### Botón de Importar Backup

```dart
ElevatedButton.icon(
  icon: Icon(Icons.download),
  label: Text('Importar Backup'),
  onPressed: () async {
    final backup = ref.read(databaseBackupServiceProvider);
    
    // Seleccionar archivo
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result == null) return;
    
    final filePath = result.files.single.path!;
    
    // Validar primero
    final validation = await backup.validateBackup(filePath);
    if (!validation.isValid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('❌ Archivo Inválido'),
          content: Text(validation.message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))],
        ),
      );
      return;
    }
    
    // Confirmar importación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️ Confirmar Importación'),
        content: Text('Esto sobrescribirá los datos actuales. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Importar')),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Importar
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()),
      );
      
      final importResult = await backup.importDatabase(filePath);
      Navigator.pop(context); // Quitar loading
      
      // Mostrar resultado
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('✅ Importación Exitosa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👥 Personas: ${importResult.personsImported}'),
              Text('📅 Eventos: ${importResult.eventsImported}'),
              Text('📊 Análisis: ${importResult.analysisImported}'),
              Text('⭐ Custom: ${importResult.customEventsImported}'),
              Divider(),
              Text('Total: ${importResult.totalImported} registros', 
                   style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK')),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Quitar loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('❌ Error'),
          content: Text('No se pudo importar: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))],
        ),
      );
    }
  },
)
```

---

## 📄 PDF Report Generator - Snippets

### Generar y Compartir Reporte Mensual

```dart
Future<void> generateMonthlyReport() async {
  final pdfGen = ref.read(pdfReportGeneratorProvider);
  
  // Obtener fechas del mes actual
  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, 1);
  final lastDay = DateTime(now.year, now.month + 1, 0);
  
  try {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generando PDF...'),
          ],
        ),
      ),
    );
    
    final pdfFile = await pdfGen.generateAttendanceReport(firstDay, lastDay);
    Navigator.pop(context); // Quitar loading
    
    // Opción 1: Vista previa
    await pdfGen.previewPDF(pdfFile);
    
    // Opción 2: Compartir directamente
    // await pdfGen.sharePDF(pdfFile);
    
  } catch (e) {
    Navigator.pop(context); // Quitar loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error al generar PDF: $e')),
    );
  }
}
```

### Botón de Reportes con Selector de Período

```dart
ElevatedButton.icon(
  icon: Icon(Icons.picture_as_pdf),
  label: Text('Generar Reporte'),
  onPressed: () async {
    // Selector de rango de fechas
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 30)),
        end: DateTime.now(),
      ),
    );
    
    if (range == null) return;
    
    final pdfGen = ref.read(pdfReportGeneratorProvider);
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(child: CircularProgressIndicator()),
      );
      
      final pdf = await pdfGen.generateAttendanceReport(range.start, range.end);
      Navigator.pop(context);
      
      // Preguntar qué hacer
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('PDF Generado'),
          content: Text('¿Qué deseas hacer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'preview'),
              child: Text('Vista Previa'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: Text('Compartir'),
            ),
          ],
        ),
      );
      
      if (action == 'preview') {
        await pdfGen.previewPDF(pdf);
      } else if (action == 'share') {
        await pdfGen.sharePDF(pdf);
      }
      
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  },
)
```

---

## 📊 Analytics Dashboard - Snippet

### Navegar al Dashboard desde Menú

```dart
ListTile(
  leading: Icon(Icons.analytics),
  title: Text('Analytics Dashboard'),
  subtitle: Text('Ver estadísticas y gráficas'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsDashboardScreen(),
      ),
    );
  },
)
```

### FloatingActionButton en Home

```dart
Scaffold(
  appBar: AppBar(title: Text('SIOMA')),
  body: /* tu contenido */,
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AnalyticsDashboardScreen()),
      );
    },
    icon: Icon(Icons.bar_chart),
    label: Text('Analytics'),
  ),
)
```

---

## 🔗 Ejemplo de Integración Completa

### Flujo de Registro con Todas las Features

```dart
Future<void> registerPersonWithAllValidations(String name, String documentId) async {
  // 1. Capturar foto
  final imagePath = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (context) => CameraScreen()),
  );
  
  if (imagePath == null) return;
  
  // 2. Validar calidad con ML Kit
  final faceDetection = ref.read(faceDetectionServiceProvider);
  final qualityResult = await faceDetection.detectFaces(imagePath);
  
  if (!qualityResult.isHighQuality) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️ Baja Calidad'),
        content: Text('Por favor, mejora la calidad de la foto'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Reintentar'))],
      ),
    );
    return;
  }
  
  // 3. Verificar liveness
  final liveness = ref.read(livenessDetectorProvider);
  liveness.startBlinkDetection();
  final livenessResult = await liveness.checkLivenessByBlink(imagePath);
  
  if (!livenessResult.isLive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('❌ Liveness Failed'),
        content: Text('No se pudo verificar que eres una persona real'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Reintentar'))],
      ),
    );
    return;
  }
  
  // 4. Generar embedding y guardar
  final embedding = ref.read(faceEmbeddingServiceProvider);
  final embeddingResult = await embedding.generateEmbedding(imagePath);
  
  final person = Person(
    name: name,
    documentId: documentId,
    embedding: embeddingResult.embeddingString,
    photoPath: imagePath,
  );
  
  final db = ref.read(databaseServiceProvider);
  await db.insertPerson(person);
  
  // 5. Crear backup automático después del registro
  final backup = ref.read(databaseBackupServiceProvider);
  await backup.exportDatabase();
  
  // 6. Mostrar confirmación
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('✅ Registro Exitoso'),
      content: Text('$name ha sido registrado correctamente'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK')),
      ],
    ),
  );
}
```

---

## 📚 Recursos Adicionales

- [Documentación Completa](docs/NUEVAS_FEATURES.md)
- [API Reference](docs/API_REFERENCE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

**¿Necesitas ayuda?** Abre un issue en GitHub o consulta la documentación completa.
