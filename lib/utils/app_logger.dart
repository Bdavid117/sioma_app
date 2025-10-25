import 'package:logger/logger.dart';

/// Sistema de logging estructurado para SIOMA
/// 
/// Niveles:
/// - debug: Información detallada para desarrollo
/// - info: Eventos importantes del sistema
/// - warning: Situaciones que requieren atención
/// - error: Errores que afectan funcionalidad
/// 
/// Uso:
/// ```dart
/// AppLogger.debug('Iniciando proceso de identificación');
/// AppLogger.info('✅ Persona registrada: ${person.name}');
/// AppLogger.warning('⚠️ Threshold bajo, ajustar a 0.65');
/// AppLogger.error('❌ Error en BD', error: e, stackTrace: stack);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    filter: _LogFilter(),
    printer: PrettyPrinter(
      methodCount: 0, // Sin stack trace en logs normales
      errorMethodCount: 5, // 5 líneas de stack en errores
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: _LogOutput(),
  );

  /// Log de nivel DEBUG - Solo en desarrollo
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nivel INFO - Eventos importantes
  static void info(String message) {
    _logger.i(message);
  }

  /// Log de nivel WARNING - Requiere atención
  static void warning(String message, {dynamic error}) {
    _logger.w(message, error: error);
  }

  /// Log de nivel ERROR - Errores críticos
  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log de nivel FATAL - Errores que causan crash
  static void fatal(String message, {required dynamic error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Cierra el logger y libera recursos
  static void close() {
    _logger.close();
  }
}

/// Filtro personalizado para controlar qué se muestra en producción
class _LogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // En producción, solo mostrar warning, error y fatal
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    
    if (isProduction) {
      return event.level.index >= Level.warning.index;
    }
    
    // En desarrollo, mostrar todo
    return true;
  }
}

/// Output personalizado (puede extenderse para guardar en archivo)
class _LogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

/// Logger especializado para operaciones biométricas
class BiometricLogger {
  // Métodos genéricos
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    AppLogger.debug('🔬 [BIOMETRIC] $message', error: error, stackTrace: stackTrace);
  }
  
  static void info(String message) {
    AppLogger.info('🔍 [BIOMETRIC] $message');
  }
  
  static void warning(String message) {
    AppLogger.warning('⚠️ [BIOMETRIC] $message');
  }
  
  static void error(String message, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.error('❌ [BIOMETRIC] $message', error: error, stackTrace: stackTrace);
  }

  /// Log de inicio de identificación
  static void identificationStart(String imagePath, double threshold) {
    AppLogger.info('🔍 Identificación 1:N iniciada');
    AppLogger.debug('   Imagen: $imagePath');
    AppLogger.debug('   Threshold: ${(threshold * 100).toStringAsFixed(1)}%');
  }

  /// Log de resultado de identificación
  static void identificationResult({
    required bool identified,
    String? personName,
    double? confidence,
    int? candidatesCount,
  }) {
    if (identified) {
      AppLogger.info('✅ Identificado: $personName (${(confidence! * 100).toStringAsFixed(1)}%)');
    } else {
      AppLogger.info('❌ No identificado (${candidatesCount ?? 0} candidatos evaluados)');
    }
  }

  /// Log de comparación de similitud
  static void similarityComparison({
    required String personName,
    required double cosine,
    required double euclidean,
    required double manhattan,
    required double combined,
  }) {
    AppLogger.debug('📊 $personName:');
    AppLogger.debug('   Coseno: ${(cosine * 100).toStringAsFixed(1)}%');
    AppLogger.debug('   Euclidiana: ${(euclidean * 100).toStringAsFixed(1)}%');
    AppLogger.debug('   Manhattan: ${(manhattan * 100).toStringAsFixed(1)}%');
    AppLogger.debug('   Combinada: ${(combined * 100).toStringAsFixed(1)}%');
  }

  /// Log de generación de embedding
  static void embeddingGenerated({
    required String imagePath,
    required int dimensions,
    required int processingTimeMs,
  }) {
    AppLogger.info('🧬 Embedding generado: ${dimensions}D en ${processingTimeMs}ms');
    AppLogger.debug('   Imagen: $imagePath');
  }

  /// Log de registro de persona
  static void personRegistered({
    required String name,
    required String documentId,
    required int embeddingDimensions,
  }) {
    AppLogger.info('👤 Persona registrada: $name ($documentId)');
    AppLogger.debug('   Embedding: ${embeddingDimensions}D');
  }
}

/// Logger especializado para base de datos
class DatabaseLogger {
  // Métodos genéricos
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    AppLogger.debug('💾 [DATABASE] $message', error: error, stackTrace: stackTrace);
  }
  
  static void info(String message) {
    AppLogger.info('💾 [DATABASE] $message');
  }
  
  static void warning(String message) {
    AppLogger.warning('⚠️ [DATABASE] $message');
  }
  
  static void error(String message, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.error('❌ [DATABASE] $message', error: error, stackTrace: stackTrace);
  }

  /// Log de operación de inserción
  static void insert(String table, {int? id}) {
    AppLogger.debug('💾 INSERT: $table${id != null ? ' (ID: $id)' : ''}');
  }

  /// Log de operación de consulta
  static void query(String table, {int? count, int? limit}) {
    AppLogger.debug('🔍 QUERY: $table (${count ?? 0} resultados${limit != null ? ', límite: $limit' : ''})');
  }

  /// Log de operación de actualización
  static void update(String table, {int? rowsAffected}) {
    AppLogger.debug('✏️ UPDATE: $table${rowsAffected != null ? ' ($rowsAffected filas)' : ''}');
  }

  /// Log de operación de eliminación
  static void delete(String table, {int? rowsAffected}) {
    AppLogger.debug('🗑️ DELETE: $table${rowsAffected != null ? ' ($rowsAffected filas)' : ''}');
  }
}

/// Logger especializado para cámara
class CameraLogger {
  // Métodos genéricos
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    AppLogger.debug('📸 [CAMERA] $message', error: error, stackTrace: stackTrace);
  }
  
  static void info(String message) {
    AppLogger.info('📸 [CAMERA] $message');
  }
  
  static void warning(String message) {
    AppLogger.warning('⚠️ [CAMERA] $message');
  }
  
  static void error(String message, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.error('❌ [CAMERA] $message', error: error, stackTrace: stackTrace);
  }

  /// Log de inicialización de cámara
  static void initialized(String cameraDescription) {
    AppLogger.info('📸 Cámara inicializada: $cameraDescription');
  }

  /// Log de captura de foto
  static void photoCapture(String path, {int? fileSize}) {
    AppLogger.info('📷 Foto capturada: ${path.split('/').last}${fileSize != null ? ' (${(fileSize / 1024).toStringAsFixed(1)}KB)' : ''}');
  }

  /// Log de permisos
  static void permissionStatus(String status) {
    AppLogger.info('🔐 Permisos de cámara: $status');
  }
}
