import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/service_providers.dart';
import '../services/face_detection_service.dart';
import '../services/liveness_detector.dart';
import '../services/realtime_scanner_service.dart';
import '../utils/app_logger.dart';
import 'analytics_dashboard_screen.dart';

/// Pantalla de demostración de todas las nuevas funcionalidades de SIOMA v2.0
class FeaturesDemoScreen extends ConsumerStatefulWidget {
  const FeaturesDemoScreen({super.key});

  @override
  ConsumerState<FeaturesDemoScreen> createState() => _FeaturesDemoScreenState();
}

class _FeaturesDemoScreenState extends ConsumerState<FeaturesDemoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Estado para ML Kit
  FaceDetectionResult? _mlKitResult;
  bool _mlKitLoading = false;
  
  // Estado para Liveness
  LivenessResult? _livenessResult;
  bool _livenessChecking = false;
  
  // Estado para Scanner
  bool _scannerActive = false;
  String _scannerStatus = 'Presiona Iniciar para comenzar';
  ScannerStatistics? _scannerStats;
  
  // Estado para Backup
  String _backupStatus = '';
  
  // Estado para PDF
  String _pdfStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_scannerActive) {
      ref.read(realtimeScannerServiceProvider).stopScanning();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 SIOMA v2.0 - Nuevas Features'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.face), text: 'ML Kit'),
            Tab(icon: Icon(Icons.remove_red_eye), text: 'Liveness'),
            Tab(icon: Icon(Icons.scanner), text: 'Scanner'),
            Tab(icon: Icon(Icons.backup), text: 'Backup'),
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMLKitDemo(),
          _buildLivenessDemo(),
          _buildScannerDemo(),
          _buildBackupDemo(),
          _buildPDFDemo(),
          _buildAnalyticsDemo(),
        ],
      ),
    );
  }

  // ============================================
  // 1. ML KIT FACE DETECTION DEMO
  // ============================================
  Widget _buildMLKitDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '🤖 Google ML Kit Face Detection',
            'Detección facial profesional con análisis de calidad en tiempo real',
          ),
          const SizedBox(height: 16),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _mlKitLoading ? null : _testMLKitWithSampleImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Probar con Imagen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _mlKitLoading ? null : _pickImageForMLKit,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar Foto'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          
          if (_mlKitLoading) ...[
            const SizedBox(height: 24),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
          
          if (_mlKitResult != null) ...[
            const SizedBox(height: 24),
            _buildMLKitResults(_mlKitResult!),
          ],
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Detección de landmarks (ojos, nariz, boca)',
            'Clasificación de ojos abiertos/cerrados',
            'Análisis de ángulo y centrado',
            'Score de calidad 0-100%',
            'Recomendaciones automáticas',
          ]),
        ],
      ),
    );
  }

  Widget _buildMLKitResults(FaceDetectionResult result) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.statusMessage,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            if (result.success && result.analysis != null) ...[
              const Divider(height: 32),
              
              // Quality Score
              Text(
                'Calidad General: ${(result.analysis!.qualityScore * 100).toInt()}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: result.analysis!.qualityScore,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(
                  result.isHighQuality ? Colors.green : Colors.orange,
                ),
                minHeight: 8,
              ),
              
              const SizedBox(height: 24),
              
              // Métricas detalladas
              const Text('Métricas Detalladas:', 
                         style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              _buildMetricRow('Centrado', result.analysis!.isCentered, 
                             result.analysis!.isCentered ? '100%' : '50%'),
              _buildMetricRow('Ángulo', result.analysis!.headAngle < 15, 
                             '${result.analysis!.headAngle.toStringAsFixed(1)}°'),
              _buildMetricRow('Ojos Abiertos', 
                             (result.analysis!.leftEyeOpen > 0.5 && result.analysis!.rightEyeOpen > 0.5), 
                             '${((result.analysis!.leftEyeOpen + result.analysis!.rightEyeOpen) / 2 * 100).toInt()}%'),
              _buildMetricRow('Sonriendo', result.analysis!.smiling > 0.3, 
                             '${(result.analysis!.smiling * 100).toInt()}%'),
            ],
            
            if (result.recommendations.isNotEmpty) ...[
              const Divider(height: 32),
              const Text('⚠️ Recomendaciones:', 
                         style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...result.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(r)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testMLKitWithSampleImage() async {
    setState(() {
      _mlKitLoading = true;
      _mlKitResult = null;
    });
    
    try {
      // Buscar una imagen de muestra en el directorio de fotos
      final dbService = ref.read(databaseServiceProvider);
      final persons = await dbService.getAllPersons();
      
      if (persons.isEmpty) {
        _showMessage('No hay personas registradas. Por favor registra una persona primero.');
        setState(() => _mlKitLoading = false);
        return;
      }
      
      final person = persons.first;
      if (person.photoPath == null || !File(person.photoPath!).existsSync()) {
        _showMessage('No se encontró foto de muestra.');
        setState(() => _mlKitLoading = false);
        return;
      }
      
      final faceDetection = ref.read(faceDetectionServiceProvider);
      final result = await faceDetection.detectFaces(person.photoPath!);
      
      setState(() {
        _mlKitResult = result;
        _mlKitLoading = false;
      });
      
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      AppLogger.error('Error en ML Kit demo', error: e);
      _showMessage('Error: $e');
      setState(() => _mlKitLoading = false);
    }
  }

  Future<void> _pickImageForMLKit() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    
    if (result == null) return;
    
    setState(() {
      _mlKitLoading = true;
      _mlKitResult = null;
    });
    
    try {
      final faceDetection = ref.read(faceDetectionServiceProvider);
      final detectionResult = await faceDetection.detectFaces(result.files.single.path!);
      
      setState(() {
        _mlKitResult = detectionResult;
        _mlKitLoading = false;
      });
      
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      AppLogger.error('Error analizando imagen', error: e);
      _showMessage('Error: $e');
      setState(() => _mlKitLoading = false);
    }
  }

  // ============================================
  // 2. LIVENESS DETECTION DEMO
  // ============================================
  Widget _buildLivenessDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '👁️ Liveness Detection (Anti-Spoofing)',
            'Verifica que se trata de una persona real, no una foto',
          ),
          const SizedBox(height: 16),
          
          // Botones
          ElevatedButton.icon(
            onPressed: _livenessChecking ? null : _simulateLivenessCheck,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Simular Verificación'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          
          if (_livenessChecking) ...[
            const SizedBox(height: 24),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analizando movimiento...', 
                       style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
          
          if (_livenessResult != null) ...[
            const SizedBox(height: 24),
            _buildLivenessResults(_livenessResult!),
          ],
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Detección de parpadeo en tiempo real',
            'Análisis de movimiento entre frames',
            'Modo combinado (blink + movement)',
            'Timeout configurable',
            'Previene ataques con fotos/pantallas',
          ]),
          
          const SizedBox(height: 16),
          _buildInfoCard(
            '💡 ¿Cómo funciona?',
            'El sistema analiza el ratio de apertura de ojos (EAR) y detecta secuencias de '
            'parpadeo (abierto → cerrado → abierto). También puede verificar movimiento '
            'significativo entre frames para mayor seguridad.',
          ),
        ],
      ),
    );
  }

  Widget _buildLivenessResults(LivenessResult result) {
    return Card(
      elevation: 4,
      color: result.isLive ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isLive ? Icons.check_circle : Icons.cancel,
                  color: result.isLive ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.isLive ? '✅ Persona Real' : '❌ No Verificado',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Mensaje: ${result.message}'),
            const SizedBox(height: 8),
            Text('Método: ${result.method}'),
            Text('Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%'),
            Text('Nivel: ${result.confidenceLevel}'),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateLivenessCheck() async {
    setState(() {
      _livenessChecking = true;
      _livenessResult = null;
    });
    
    // Simular proceso de verificación
    await Future.delayed(const Duration(seconds: 2));
    
    // Simular resultado exitoso
    final mockResult = LivenessResult(
      isLive: true,
      confidence: 0.95,
      method: 'blink',
      message: 'Parpadeo detectado exitosamente',
    );
    
    setState(() {
      _livenessResult = mockResult;
      _livenessChecking = false;
    });
    
    HapticFeedback.heavyImpact();
    _showMessage('✅ Liveness verificado exitosamente!');
  }

  // ============================================
  // 3. REALTIME SCANNER DEMO
  // ============================================
  Widget _buildScannerDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '📱 Realtime Scanner',
            'Scanner continuo con throttling y estadísticas en tiempo real',
          ),
          const SizedBox(height: 16),
          
          // Controles
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scannerActive ? _stopScanner : _startScanner,
                  icon: Icon(_scannerActive ? Icons.stop : Icons.play_arrow),
                  label: Text(_scannerActive ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _scannerActive ? Colors.red : Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resetScannerStats,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Stats'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Estado actual
          Card(
            elevation: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _scannerActive ? Colors.blue[50] : Colors.grey[100],
              child: Column(
                children: [
                  Icon(
                    _scannerActive ? Icons.radar : Icons.pause_circle_outline,
                    size: 48,
                    color: _scannerActive ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scannerStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          
          if (_scannerStats != null) ...[
            const SizedBox(height: 24),
            _buildScannerStatistics(_scannerStats!),
          ],
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Procesamiento con throttling (cada 2s)',
            'Cooldown entre identificaciones (5s)',
            'Validación de calidad previa',
            'Estadísticas en tiempo real',
            'Callbacks para feedback inmediato',
          ]),
        ],
      ),
    );
  }

  Widget _buildScannerStatistics(ScannerStatistics stats) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Estadísticas', 
                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _buildStatRow('Frames Procesados', '${stats.framesProcessed}', Icons.camera),
            _buildStatRow('Rostros Detectados', '${stats.facesDetected}', Icons.face),
            _buildStatRow('Identificaciones Intentadas', '${stats.identificationsAttempted}', Icons.search),
            _buildStatRow('Identificaciones Exitosas', '${stats.identificationsSuccessful}', Icons.check_circle),
            _buildStatRow(
              'Tasa de Detección', 
              '${(stats.faceDetectionRate * 100).toStringAsFixed(1)}%',
              Icons.percent,
            ),
            _buildStatRow(
              'Tasa de Éxito', 
              '${(stats.identificationSuccessRate * 100).toStringAsFixed(1)}%',
              Icons.stars,
            ),
          ],
        ),
      ),
    );
  }

  void _startScanner() {
    // Simulación del scanner (sin cámara real)
    setState(() {
      _scannerActive = true;
      _scannerStatus = '🔍 Scanner activo (Demo Mode)';
      _scannerStats = ScannerStatistics(
        framesProcessed: 0,
        facesDetected: 0,
        identificationsAttempted: 0,
        identificationsSuccessful: 0,
        isActive: true,
        isProcessing: false,
      );
    });
    
    _showMessage('Scanner iniciado en modo demostración');
  }

  void _stopScanner() {
    setState(() {
      _scannerActive = false;
      _scannerStatus = 'Scanner detenido';
    });
  }

  void _resetScannerStats() {
    setState(() {
      _scannerStats = null;
      _scannerStatus = 'Estadísticas reiniciadas';
      _scannerActive = false;
    });
  }

  // ============================================
  // 4. DATABASE BACKUP DEMO
  // ============================================
  Widget _buildBackupDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '💾 Database Backup & Restore',
            'Exporta e importa toda la base de datos en formato JSON',
          ),
          const SizedBox(height: 16),
          
          // Botones de acción
          ElevatedButton.icon(
            onPressed: _exportBackup,
            icon: const Icon(Icons.upload_file),
            label: const Text('Exportar Backup'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue,
            ),
          ),
          
          const SizedBox(height: 12),
          
          ElevatedButton.icon(
            onPressed: _importBackup,
            icon: const Icon(Icons.download),
            label: const Text('Importar Backup'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.green,
            ),
          ),
          
          if (_backupStatus.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_backupStatus)),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Exportación completa a JSON',
            'Incluye personas, eventos y análisis',
            'Validación de estructura',
            'Compartir vía share_plus',
            'Migración entre dispositivos',
          ]),
          
          const SizedBox(height: 16),
          _buildInfoCard(
            '💡 Formato del Backup',
            'El backup se guarda en formato JSON con toda la información: '
            'personas (con embeddings), eventos de identificación, eventos de análisis '
            'y eventos personalizados. Perfecto para migración o respaldo.',
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _backupStatus = 'Generando backup...');
    
    try {
      final backup = ref.read(databaseBackupServiceProvider);
      final file = await backup.exportDatabase();
      
      final sizeKB = (file.lengthSync() / 1024).toStringAsFixed(1);
      
      setState(() {
        _backupStatus = '✅ Backup exportado: $sizeKB KB\n📂 ${file.path}';
      });
      
      // Mostrar opciones para compartir
      _showMessage('Backup creado exitosamente');
      
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      AppLogger.error('Error exportando backup', error: e);
      setState(() => _backupStatus = '❌ Error: $e');
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result == null) return;
    
    setState(() => _backupStatus = 'Importando backup...');
    
    try {
      final backup = ref.read(databaseBackupServiceProvider);
      final filePath = result.files.single.path!;
      
      // Guardar contexto antes de operaciones async
      if (!mounted) return;
      
      // Confirmar
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Confirmar'),
          content: const Text('Esto sobrescribirá los datos actuales. ¿Continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );
      
      if (confirm != true) {
        setState(() => _backupStatus = 'Importación cancelada');
        return;
      }
      
      setState(() => _backupStatus = 'Importando datos...');
      
      final importResult = await backup.importDatabase(File(filePath));
      
      setState(() {
        _backupStatus = '✅ Importación exitosa!\n'
            '👥 Personas: ${importResult.personsImported}\n'
            '📅 Eventos: ${importResult.eventsImported}';
      });
      
      HapticFeedback.heavyImpact();
      
    } catch (e) {
      AppLogger.error('Error importando backup', error: e);
      setState(() => _backupStatus = '❌ Error: $e');
    }
  }

  // ============================================
  // 5. PDF REPORT GENERATOR DEMO
  // ============================================
  Widget _buildPDFDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '📄 PDF Report Generator',
            'Genera reportes profesionales con estadísticas y gráficos',
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _generatePDFReport,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generar Reporte (Últimos 30 días)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.red,
            ),
          ),
          
          if (_pdfStatus.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_pdfStatus)),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Encabezado con período y fecha',
            'Tarjetas de estadísticas clave',
            'Tabla de eventos (últimos 50)',
            'Diseño profesional corporativo',
            'Vista previa antes de compartir',
            'Exportar vía email/WhatsApp',
          ]),
          
          const SizedBox(height: 16),
          _buildInfoCard(
            '💡 Contenido del Reporte',
            'El reporte PDF incluye: encabezado con período, 3 tarjetas de estadísticas '
            '(total eventos, personas únicas, confianza promedio), tabla detallada de '
            'eventos con fecha/hora, nombre, documento, tipo y confianza.',
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDFReport() async {
    setState(() => _pdfStatus = 'Generando reporte PDF...');
    
    try {
      final pdfGen = ref.read(pdfReportGeneratorProvider);
      
      // Últimos 30 días
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      
      final file = await pdfGen.generateAttendanceReport(
        startDate: startDate,
        endDate: endDate,
      );
      
      final sizeKB = (file.lengthSync() / 1024).toStringAsFixed(1);
      
      setState(() {
        _pdfStatus = '✅ PDF generado: $sizeKB KB\n📂 ${file.path}';
      });
      
      _showMessage('PDF generado exitosamente');
      
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      AppLogger.error('Error generando PDF', error: e);
      setState(() => _pdfStatus = '❌ Error: $e');
    }
  }

  // ============================================
  // 6. ANALYTICS DASHBOARD DEMO
  // ============================================
  Widget _buildAnalyticsDemo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '📊 Analytics Dashboard',
            'Visualización de datos con gráficas interactivas',
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsDashboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
            label: const Text('Abrir Dashboard Completo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.purple,
            ),
          ),
          
          const SizedBox(height: 24),
          _buildFeaturesList([
            'Tarjetas de estadísticas (Cards)',
            'Gráfica de barras: Eventos por día',
            'Gráfica de líneas: Tendencia de confianza',
            'Top 5 personas más identificadas',
            'Distribución de niveles de confianza',
            'Actualización automática cada 30s',
            'Pull-to-refresh manual',
          ]),
          
          const SizedBox(height: 16),
          _buildInfoCard(
            '💡 Visualizaciones',
            'El dashboard utiliza fl_chart para mostrar gráficas interactivas. '
            'Incluye gráficas de barras para eventos diarios, líneas para tendencias '
            'de confianza, y listas con las personas más identificadas.',
          ),
          
          const SizedBox(height: 24),
          
          // Preview de métricas
          const Text('Vista Previa de Métricas:', 
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Total Eventos', '1,234', Icons.event, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Personas', '156', Icons.people, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Confianza', '94.5%', Icons.stars, Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('Hoy', '45', Icons.today, Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // WIDGETS AUXILIARES
  // ============================================
  
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesList(List<String> features) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Características:', 
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✓ ', style: TextStyle(color: Colors.green, fontSize: 16)),
                  Expanded(child: Text(f)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, bool value, String score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            score,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
