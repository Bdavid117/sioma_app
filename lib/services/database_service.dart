import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/person.dart';
import '../models/identification_event.dart';
import '../models/analysis_event.dart';
import '../models/custom_event.dart';
import '../utils/validation_utils.dart';
import '../utils/app_logger.dart';

/// Servicio para gestionar la base de datos SQLite local
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'sioma_biometric.db');

    final db = await openDatabase(
      path,
      version: 6, // v6: Agregado photo_path y confidence a custom_events
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    
    // Verificar y corregir esquema si es necesario
    await _verifyAndFixSchema(db);
    
    return db;
  }
  
  /// Verifica que todas las columnas necesarias existan y las agrega si faltan
  Future<void> _verifyAndFixSchema(Database db) async {
    try {
      // Verificar columnas de custom_events
      final tableInfo = await db.rawQuery('PRAGMA table_info(custom_events)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toList();
      
      // Agregar photo_path si no existe
      if (!columnNames.contains('photo_path')) {
        DatabaseLogger.info('🔧 Agregando columna photo_path a custom_events');
        await db.execute('ALTER TABLE custom_events ADD COLUMN photo_path TEXT');
      }
      
      // Agregar confidence si no existe
      if (!columnNames.contains('confidence')) {
        DatabaseLogger.info('🔧 Agregando columna confidence a custom_events');
        await db.execute('ALTER TABLE custom_events ADD COLUMN confidence REAL');
      }
      
      DatabaseLogger.info('✅ Esquema de base de datos verificado y actualizado');
    } catch (e) {
      DatabaseLogger.error('Error verificando esquema de BD', e);
    }
  }

  /// Crea las tablas de la base de datos
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de personas registradas
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        document_id TEXT NOT NULL UNIQUE,
        photo_path TEXT,
        embedding TEXT NOT NULL,
        metadata TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla de eventos de identificación
    await db.execute('''
      CREATE TABLE identification_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER,
        person_name TEXT,
        confidence REAL,
        photo_path TEXT,
        timestamp TEXT NOT NULL,
        identified INTEGER NOT NULL,
        FOREIGN KEY (person_id) REFERENCES persons (id)
      )
    ''');

    // Tabla de eventos de análisis detallados (v2.0)
    await db.execute('''
      CREATE TABLE analysis_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        analysis_type TEXT NOT NULL,
        was_successful INTEGER NOT NULL,
        identified_person_id INTEGER,
        identified_person_name TEXT,
        confidence REAL,
        processing_time_ms INTEGER NOT NULL,
        metadata TEXT NOT NULL,
        device_info TEXT NOT NULL,
        app_version TEXT NOT NULL,
        FOREIGN KEY (identified_person_id) REFERENCES persons (id)
      )
    ''');

    // Tabla de eventos personalizados (v3.0)
    await db.execute('''
      CREATE TABLE custom_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        person_name TEXT NOT NULL,
        person_document TEXT NOT NULL,
        event_type TEXT NOT NULL,
        event_name TEXT NOT NULL,
        location TEXT NOT NULL,
        location_description TEXT,
        status TEXT NOT NULL DEFAULT 'completado',
        timestamp TEXT NOT NULL,
        notes TEXT,
        metadata TEXT,
        photo_path TEXT,
        confidence REAL,
        FOREIGN KEY (person_id) REFERENCES persons (id)
      )
    ''');

    // Índices para mejorar el rendimiento
    await db.execute(
      'CREATE INDEX idx_document_id ON persons(document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_persons_name ON persons(name)',
    );
    await db.execute(
      'CREATE INDEX idx_persons_created_at ON persons(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_timestamp ON identification_events(timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_events_person_id ON identification_events(person_id)',
    );
    await db.execute(
      'CREATE INDEX idx_events_identified ON identification_events(identified)',
    );
    await db.execute(
      'CREATE INDEX idx_analysis_timestamp ON analysis_events(timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_analysis_type ON analysis_events(analysis_type)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_events_timestamp ON custom_events(timestamp DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_events_type ON custom_events(event_type)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_events_person ON custom_events(person_id)',
    );
    
    DatabaseLogger.info('Database created successfully with all tables and indexes');
  }

  /// Actualiza la base de datos a versiones nuevas
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar tabla de análisis detallados
      await db.execute('''
        CREATE TABLE analysis_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          image_path TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          analysis_type TEXT NOT NULL,
          was_successful INTEGER NOT NULL,
          identified_person_id INTEGER,
          identified_person_name TEXT,
          confidence REAL,
          processing_time_ms INTEGER NOT NULL,
          metadata TEXT NOT NULL,
          device_info TEXT NOT NULL,
          app_version TEXT NOT NULL,
          FOREIGN KEY (identified_person_id) REFERENCES persons (id)
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_analysis_timestamp ON analysis_events(timestamp DESC)',
      );
      await db.execute(
        'CREATE INDEX idx_analysis_type ON analysis_events(analysis_type)',
      );
      
      DatabaseLogger.info('Upgraded to version 2: Added analysis_events table');
    }

    if (oldVersion < 3) {
      // Agregar tabla de eventos personalizados
      await db.execute('''
        CREATE TABLE custom_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          person_id INTEGER NOT NULL,
          person_name TEXT NOT NULL,
          person_document TEXT NOT NULL,
          event_type TEXT NOT NULL,
          event_name TEXT NOT NULL,
          location TEXT NOT NULL,
          location_description TEXT,
          status TEXT NOT NULL DEFAULT 'completado',
          timestamp TEXT NOT NULL,
          notes TEXT,
          metadata TEXT,
          FOREIGN KEY (person_id) REFERENCES persons (id)
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_custom_events_timestamp ON custom_events(timestamp DESC)',
      );
      await db.execute(
        'CREATE INDEX idx_custom_events_type ON custom_events(event_type)',
      );
      await db.execute(
        'CREATE INDEX idx_custom_events_person ON custom_events(person_id)',
      );
      
      DatabaseLogger.info('Upgraded to version 3: Added custom_events table');
    }
    
    // Versión 4: Agregar índices adicionales para optimización
    if (oldVersion < 4) {
      // Solo crear índices si no existen
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_persons_created_at ON persons(created_at DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_person_id ON identification_events(person_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_identified ON identification_events(identified)',
      );
      
      DatabaseLogger.info('Upgraded to version 4: Added performance indexes');
    }
    
    // Versión 5: Agregar campo metadata a persons para ML Kit Face Detection
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE persons ADD COLUMN metadata TEXT',
      );
      
      DatabaseLogger.info('Upgraded to version 5: Added metadata column to persons for ML Kit');
    }
    
    // Versión 6: Agregar photo_path y confidence a custom_events
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE custom_events ADD COLUMN photo_path TEXT',
      );
      await db.execute(
        'ALTER TABLE custom_events ADD COLUMN confidence REAL',
      );
      
      DatabaseLogger.info('Upgraded to version 6: Added photo_path and confidence columns to custom_events');
    }
  }

  // ==================== OPERACIONES PERSONS ====================

  /// Inserta una nueva persona con validaciones de seguridad
  Future<int> insertPerson(Person person) async {
    try {
      // Validar datos de entrada
      final nameValidation = ValidationUtils.validatePersonName(person.name);
      if (!nameValidation.isValid) {
        throw SiomaValidationException(nameValidation.error!, 'name');
      }

      final documentValidation = ValidationUtils.validateDocumentId(person.documentId);
      if (!documentValidation.isValid) {
        throw SiomaValidationException(documentValidation.error!, 'documentId');
      }

      final embeddingValidation = ValidationUtils.validateEmbeddingJson(person.embedding);
      if (!embeddingValidation.isValid) {
        throw SiomaValidationException(embeddingValidation.error!, 'embedding');
      }

      if (person.photoPath != null) {
        final pathValidation = ValidationUtils.validateFilePath(person.photoPath!);
        if (!pathValidation.isValid) {
          throw SiomaValidationException(pathValidation.error!, 'photoPath');
        }
      }

      // Verificar si el documento ya existe
      final existingPerson = await getPersonByDocument(documentValidation.value!);
      if (existingPerson != null) {
        throw SiomaDatabaseException('Ya existe una persona registrada con el documento: ${documentValidation.value}');
      }

      // Crear persona con datos validados
      final validatedPerson = Person(
        name: nameValidation.value!,
        documentId: documentValidation.value!,
        photoPath: person.photoPath,
        embedding: embeddingValidation.value!,
        metadata: person.metadata, // ✅ INCLUIR METADATA ML KIT
        createdAt: person.createdAt,
      );

      final db = await database;
      final id = await db.insert('persons', validatedPerson.toMap());

      DatabaseLogger.info('Person inserted successfully: ID=$id, Document=${validatedPerson.documentId}, Metadata=${person.metadata != null ? "YES (${person.metadata!.keys.length} fields)" : "NO"}');
      return id;
    } on SiomaValidationException {
      rethrow;
    } on SiomaDatabaseException {
      rethrow;
    } catch (e) {
      DatabaseLogger.error('Error inserting person', e);
      throw SiomaDatabaseException('Error al insertar persona en la base de datos', e.toString());
    }
  }

  /// Obtiene todas las personas con límites de seguridad y paginación optimizada
  /// 
  /// [limit] - Número máximo de resultados (máx 1000, por defecto 100)
  /// [offset] - Número de registros a saltar para paginación
  /// [orderBy] - Campo para ordenar (por defecto 'created_at DESC')
  Future<List<Person>> getAllPersons({
    int? limit, 
    int? offset,
    String orderBy = 'created_at DESC',
  }) async {
    try {
      final db = await database;

      // Aplicar límite de seguridad (máximo 1000 registros por consulta)
      final safeLimit = limit != null ? (limit > 1000 ? 1000 : limit) : 100;
      final safeOffset = offset ?? 0;

      DatabaseLogger.debug('Querying persons: limit=$safeLimit, offset=$safeOffset, orderBy=$orderBy');

      final List<Map<String, dynamic>> maps = await db.query(
        'persons',
        orderBy: orderBy,
        limit: safeLimit,
        offset: safeOffset,
      );

      DatabaseLogger.debug('Retrieved ${maps.length} persons from database');
      return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting all persons', e);
      throw SiomaDatabaseException('Error al obtener la lista de personas', e.toString());
    }
  }

  /// Busca personas por nombre o documento con paginación
  /// 
  /// Usa índices en 'name' y 'document_id' para búsqueda eficiente
  Future<List<Person>> searchPersons({
    required String query,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      
      // Aplicar límite de seguridad
      final safeLimit = limit != null ? (limit > 500 ? 500 : limit) : 50;
      final safeOffset = offset ?? 0;
      
      final searchPattern = '%${query.toLowerCase()}%';
      
      DatabaseLogger.debug('Searching persons: query="$query", limit=$safeLimit');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'persons',
        where: 'LOWER(name) LIKE ? OR LOWER(document_id) LIKE ?',
        whereArgs: [searchPattern, searchPattern],
        orderBy: 'name ASC',
        limit: safeLimit,
        offset: safeOffset,
      );
      
      DatabaseLogger.debug('Found ${maps.length} persons matching query');
      return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error searching persons', e);
      throw SiomaDatabaseException('Error al buscar personas', e.toString());
    }
  }

  /// Obtiene una persona por ID
  Future<Person?> getPersonById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'persons',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Person.fromMap(maps.first);
  }

  /// Obtiene una persona por documento con validación de entrada
  Future<Person?> getPersonByDocument(String documentId) async {
    try {
      // Validar entrada para prevenir inyección SQL
      final documentValidation = ValidationUtils.validateDocumentId(documentId);
      if (!documentValidation.isValid) {
        DatabaseLogger.warning('Invalid document ID provided: $documentId');
        return null; // Retorna null en lugar de lanzar excepción para búsquedas
      }

      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'persons',
        where: 'document_id = ?',
        whereArgs: [documentValidation.value!],
        limit: 1, // Limitar resultados por seguridad
      );

      if (maps.isEmpty) return null;
      return Person.fromMap(maps.first);
    } catch (e) {
      DatabaseLogger.error('Error getting person by document', e);
      return null;
    }
  }

  /// Actualiza una persona
  Future<int> updatePerson(Person person) async {
    final db = await database;
    return await db.update(
      'persons',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  /// Elimina una persona
  Future<int> deletePerson(int id) async {
    final db = await database;
    return await db.delete(
      'persons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtiene el conteo total de personas
  /// Usa COUNT(*) optimizado que aprovecha los índices
  Future<int> getPersonsCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM persons');
      final count = Sqflite.firstIntValue(result) ?? 0;
      DatabaseLogger.debug('Total persons count: $count');
      return count;
    } catch (e) {
      DatabaseLogger.error('Error getting persons count', e);
      return 0;
    }
  }

  /// Obtiene estadísticas de la base de datos
  Future<DatabaseStats> getDatabaseStats() async {
    try {
      final db = await database;
      
      final personsCount = await getPersonsCount();
      final eventsResult = await db.rawQuery('SELECT COUNT(*) as count FROM identification_events');
      final eventsCount = Sqflite.firstIntValue(eventsResult) ?? 0;
      
      final analysisResult = await db.rawQuery('SELECT COUNT(*) as count FROM analysis_events');
      final analysisCount = Sqflite.firstIntValue(analysisResult) ?? 0;
      
      final customEventsResult = await db.rawQuery('SELECT COUNT(*) as count FROM custom_events');
      final customEventsCount = Sqflite.firstIntValue(customEventsResult) ?? 0;
      
      // Obtener tamaño estimado de la base de datos
      final sizeResult = await db.rawQuery('SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
      final dbSize = Sqflite.firstIntValue(sizeResult) ?? 0;
      
      final stats = DatabaseStats(
        personsCount: personsCount,
        eventsCount: eventsCount,
        analysisCount: analysisCount,
        customEventsCount: customEventsCount,
        databaseSizeBytes: dbSize,
        databaseSizeMB: (dbSize / (1024 * 1024)),
        totalRecords: personsCount + eventsCount + analysisCount + customEventsCount,
      );
      
      DatabaseLogger.info('Database stats: ${stats.toString()}');
      return stats;
    } catch (e) {
      DatabaseLogger.error('Error getting database stats', e);
      return DatabaseStats.empty();
    }
  }

  /// Optimiza la base de datos ejecutando VACUUM y ANALYZE
  /// 
  /// VACUUM: Reconstruye la base de datos, liberando espacio no utilizado
  /// ANALYZE: Actualiza estadísticas de índices para mejorar el query planner
  Future<void> optimizeDatabase() async {
    try {
      final db = await database;
      
      DatabaseLogger.info('Starting database optimization...');
      
      // ANALYZE actualiza las estadísticas de los índices
      await db.execute('ANALYZE');
      DatabaseLogger.debug('ANALYZE completed');
      
      // VACUUM reconstruye la base de datos (puede tardar en bases grandes)
      await db.execute('VACUUM');
      DatabaseLogger.debug('VACUUM completed');
      
      DatabaseLogger.info('Database optimization completed successfully');
    } catch (e) {
      DatabaseLogger.error('Error optimizing database', e);
      throw SiomaDatabaseException('Error al optimizar la base de datos', e.toString());
    }
  }

  // ==================== OPERACIONES EVENTS ====================

  /// Inserta un nuevo evento de identificación
  Future<int> insertIdentificationEvent(IdentificationEvent event) async {
    try {
      final db = await database;
      final id = await db.insert('identification_events', event.toMap());
      DatabaseLogger.debug('Identification event inserted: ID=$id');
      return id;
    } catch (e) {
      DatabaseLogger.error('Error inserting identification event', e);
      throw SiomaDatabaseException('Error al insertar evento de identificación', e.toString());
    }
  }

  /// Obtiene todos los eventos de identificación con paginación
  /// 
  /// Usa índice idx_timestamp para ordenamiento eficiente
  Future<List<IdentificationEvent>> getAllEvents({
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      
      final safeLimit = limit != null ? (limit > 1000 ? 1000 : limit) : 100;
      final safeOffset = offset ?? 0;
      
      DatabaseLogger.debug('Querying events: limit=$safeLimit, offset=$safeOffset');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'identification_events',
        orderBy: 'timestamp DESC', // Usa idx_timestamp
        limit: safeLimit,
        offset: safeOffset,
      );
      
      return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting all events', e);
      throw SiomaDatabaseException('Error al obtener eventos', e.toString());
    }
  }

  /// Obtiene eventos por persona (usa índice idx_events_person_id)
  Future<List<IdentificationEvent>> getEventsByPerson(
    int personId, {
    int? limit,
  }) async {
    try {
      final db = await database;
      
      final safeLimit = limit ?? 100;
      
      DatabaseLogger.debug('Querying events for person: ID=$personId, limit=$safeLimit');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'identification_events',
        where: 'person_id = ?', // Usa idx_events_person_id
        whereArgs: [personId],
        orderBy: 'timestamp DESC',
        limit: safeLimit,
      );
      
      return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting events by person', e);
      throw SiomaDatabaseException('Error al obtener eventos de la persona', e.toString());
    }
  }

  /// Obtiene eventos por rango de fechas (usa índice idx_timestamp)
  Future<List<IdentificationEvent>> getEventsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  }) async {
    try {
      final db = await database;
      
      final safeLimit = limit ?? 500;
      
      DatabaseLogger.debug('Querying events by date range: $startDate to $endDate');
      
      final List<Map<String, dynamic>> maps = await db.query(
        'identification_events',
        where: 'timestamp BETWEEN ? AND ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'timestamp DESC', // Usa idx_timestamp
        limit: safeLimit,
      );
      
      return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting events by date range', e);
      throw SiomaDatabaseException('Error al obtener eventos por rango de fechas', e.toString());
    }
  }

  /// Obtiene solo eventos identificados (usa índice idx_events_identified)
  Future<List<IdentificationEvent>> getSuccessfulEvents({
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      
      final safeLimit = limit ?? 100;
      final safeOffset = offset ?? 0;
      
      final List<Map<String, dynamic>> maps = await db.query(
        'identification_events',
        where: 'identified = 1', // Usa idx_events_identified
        orderBy: 'timestamp DESC',
        limit: safeLimit,
        offset: safeOffset,
      );
      
      return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting successful events', e);
      throw SiomaDatabaseException('Error al obtener eventos exitosos', e.toString());
    }
  }

  /// Obtiene el conteo de eventos
  Future<int> getEventsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM identification_events');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Elimina eventos antiguos (opcional, para mantenimiento)
  Future<int> deleteOldEvents(DateTime beforeDate) async {
    final db = await database;
    return await db.delete(
      'identification_events',
      where: 'timestamp < ?',
      whereArgs: [beforeDate.toIso8601String()],
    );
  }

  // ==================== OPERACIONES ANALYSIS EVENTS ====================

  /// Inserta un nuevo evento de análisis detallado
  Future<int> insertAnalysisEvent(AnalysisEvent event) async {
    try {
      final db = await database;
      final result = await db.insert('analysis_events', event.toMap());
      
      DatabaseLogger.info('Evento de análisis registrado: ${event.analysisType} - ${event.wasSuccessful ? "Exitoso" : "Fallido"}');
      
      return result;
    } catch (e) {
      DatabaseLogger.error('Error al insertar evento de análisis', e);
      rethrow;
    }
  }

  /// Obtiene todos los eventos de análisis
  Future<List<AnalysisEvent>> getAllAnalysisEvents({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analysis_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => AnalysisEvent.fromMap(maps[i]));
  }

  /// Obtiene eventos de análisis por tipo
  Future<List<AnalysisEvent>> getAnalysisEventsByType(String analysisType, {int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analysis_events',
      where: 'analysis_type = ?',
      whereArgs: [analysisType],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => AnalysisEvent.fromMap(maps[i]));
  }

  /// Obtiene eventos de análisis por persona identificada
  Future<List<AnalysisEvent>> getAnalysisEventsByPerson(int personId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analysis_events',
      where: 'identified_person_id = ?',
      whereArgs: [personId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => AnalysisEvent.fromMap(maps[i]));
  }

  /// Obtiene estadísticas de análisis
  Future<Map<String, dynamic>> getAnalysisStatistics() async {
    final db = await database;
    
    // Conteo total
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM analysis_events');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;
    
    // Exitosos vs fallidos
    final successResult = await db.rawQuery('SELECT COUNT(*) as count FROM analysis_events WHERE was_successful = 1');
    final successful = Sqflite.firstIntValue(successResult) ?? 0;
    
    // Por tipo de análisis
    final typeResult = await db.rawQuery('''
      SELECT analysis_type, COUNT(*) as count 
      FROM analysis_events 
      GROUP BY analysis_type
    ''');
    
    // Tiempo promedio de procesamiento
    final avgTimeResult = await db.rawQuery('SELECT AVG(processing_time_ms) as avg_time FROM analysis_events');
    final avgProcessingTime = avgTimeResult.first['avg_time'] as double? ?? 0.0;
    
    // Eventos recientes (últimas 24 horas)
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final recentResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM analysis_events 
      WHERE timestamp > ?
    ''', [yesterday.toIso8601String()]);
    final recentCount = Sqflite.firstIntValue(recentResult) ?? 0;
    
    return {
      'total_events': total,
      'successful_events': successful,
      'failed_events': total - successful,
      'success_rate': total > 0 ? (successful / total * 100) : 0.0,
      'events_by_type': Map.fromEntries(
        typeResult.map((row) => MapEntry(
          row['analysis_type'] as String,
          row['count'] as int,
        )),
      ),
      'avg_processing_time_ms': avgProcessingTime,
      'recent_events_24h': recentCount,
    };
  }

  /// Obtiene eventos de análisis en un rango de fechas
  Future<List<AnalysisEvent>> getAnalysisEventsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analysis_events',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => AnalysisEvent.fromMap(maps[i]));
  }

  /// Elimina eventos de análisis antiguos
  Future<int> deleteOldAnalysisEvents(DateTime beforeDate) async {
    final db = await database;
    return await db.delete(
      'analysis_events',
      where: 'timestamp < ?',
      whereArgs: [beforeDate.toIso8601String()],
    );
  }

  /// Obtiene el conteo de eventos de análisis
  Future<int> getAnalysisEventsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM analysis_events');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== OPERACIONES CUSTOM EVENTS ====================

  /// Inserta un nuevo evento personalizado
  Future<int> insertCustomEvent(CustomEvent event) async {
    try {
      final db = await database;
      final id = await db.insert('custom_events', event.toMap());
      DatabaseLogger.info('Custom event inserted successfully: ID=$id, Type=${event.eventType}');
      return id;
    } catch (e) {
      DatabaseLogger.error('Error inserting custom event', e);
      throw SiomaDatabaseException('Error al insertar evento personalizado', e.toString());
    }
  }

  /// Obtiene todos los eventos personalizados
  Future<List<CustomEvent>> getAllCustomEvents({int? limit, String? eventType}) async {
    try {
      final db = await database;
      
      String query = 'custom_events';
      List<dynamic> whereArgs = [];
      String? where;
      
      if (eventType != null) {
        where = 'event_type = ?';
        whereArgs.add(eventType);
      }
      
      final List<Map<String, dynamic>> maps = await db.query(
        query,
        where: where,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      
      return List.generate(maps.length, (i) => CustomEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting custom events', e);
      throw SiomaDatabaseException('Error al obtener eventos personalizados', e.toString());
    }
  }

  /// Obtiene eventos personalizados por persona
  Future<List<CustomEvent>> getCustomEventsByPerson(int personId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'custom_events',
        where: 'person_id = ?',
        whereArgs: [personId],
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => CustomEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting custom events by person', e);
      throw SiomaDatabaseException('Error al obtener eventos por persona', e.toString());
    }
  }

  /// Obtiene eventos personalizados por tipo
  Future<List<CustomEvent>> getCustomEventsByType(String eventType, {int? limit}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'custom_events',
        where: 'event_type = ?',
        whereArgs: [eventType],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return List.generate(maps.length, (i) => CustomEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting custom events by type', e);
      throw SiomaDatabaseException('Error al obtener eventos por tipo', e.toString());
    }
  }

  /// Obtiene eventos personalizados en un rango de fechas
  Future<List<CustomEvent>> getCustomEventsByDateRange(
    DateTime startDate, 
    DateTime endDate, {
    String? eventType,
  }) async {
    try {
      final db = await database;
      
      String where = 'timestamp BETWEEN ? AND ?';
      List<dynamic> whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
      
      if (eventType != null) {
        where += ' AND event_type = ?';
        whereArgs.add(eventType);
      }
      
      final List<Map<String, dynamic>> maps = await db.query(
        'custom_events',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
      );
      
      return List.generate(maps.length, (i) => CustomEvent.fromMap(maps[i]));
    } catch (e) {
      DatabaseLogger.error('Error getting custom events by date range', e);
      throw SiomaDatabaseException('Error al obtener eventos por rango de fechas', e.toString());
    }
  }

  /// Actualiza un evento personalizado
  Future<void> updateCustomEvent(CustomEvent event) async {
    try {
      final db = await database;
      await db.update(
        'custom_events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      DatabaseLogger.info('Custom event updated successfully: ID=${event.id}');
    } catch (e) {
      DatabaseLogger.error('Error updating custom event', e);
      throw SiomaDatabaseException('Error al actualizar evento personalizado', e.toString());
    }
  }

  /// Elimina un evento personalizado
  Future<void> deleteCustomEvent(int eventId) async {
    try {
      final db = await database;
      await db.delete(
        'custom_events',
        where: 'id = ?',
        whereArgs: [eventId],
      );
      DatabaseLogger.info('Custom event deleted successfully: ID=$eventId');
    } catch (e) {
      DatabaseLogger.error('Error deleting custom event', e);
      throw SiomaDatabaseException('Error al eliminar evento personalizado', e.toString());
    }
  }

  /// Obtiene estadísticas de eventos personalizados
  Future<Map<String, dynamic>> getCustomEventsStatistics() async {
    try {
      final db = await database;
      
      // Conteo total
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM custom_events');
      final total = Sqflite.firstIntValue(totalResult) ?? 0;
      
      // Por tipo de evento
      final typeResult = await db.rawQuery('''
        SELECT event_type, COUNT(*) as count 
        FROM custom_events 
        GROUP BY event_type
      ''');
      
      // Por estado
      final statusResult = await db.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM custom_events 
        GROUP BY status
      ''');
      
      // Eventos de hoy
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final todayResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM custom_events 
        WHERE timestamp BETWEEN ? AND ?
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);
      final todayCount = Sqflite.firstIntValue(todayResult) ?? 0;
      
      // Eventos de esta semana
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final weekResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM custom_events 
        WHERE timestamp >= ?
      ''', [startOfWeek.toIso8601String()]);
      final weekCount = Sqflite.firstIntValue(weekResult) ?? 0;
      
      return {
        'total_events': total,
        'events_today': todayCount,
        'events_this_week': weekCount,
        'events_by_type': Map.fromEntries(
          typeResult.map((row) => MapEntry(
            row['event_type'] as String,
            row['count'] as int,
          )),
        ),
        'events_by_status': Map.fromEntries(
          statusResult.map((row) => MapEntry(
            row['status'] as String,
            row['count'] as int,
          )),
        ),
      };
    } catch (e) {
      DatabaseLogger.error('Error getting custom events statistics', e);
      throw SiomaDatabaseException('Error al obtener estadísticas de eventos', e.toString());
    }
  }

  /// Obtiene el conteo de eventos personalizados
  Future<int> getCustomEventsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM custom_events');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Elimina la base de datos (útil para desarrollo/testing)
  Future<void> deleteDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'sioma_biometric.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

/// Estadísticas de la base de datos
class DatabaseStats {
  final int personsCount;
  final int eventsCount;
  final int analysisCount;
  final int customEventsCount;
  final int databaseSizeBytes;
  final double databaseSizeMB;
  final int totalRecords;

  DatabaseStats({
    required this.personsCount,
    required this.eventsCount,
    required this.analysisCount,
    required this.customEventsCount,
    required this.databaseSizeBytes,
    required this.databaseSizeMB,
    required this.totalRecords,
  });

  factory DatabaseStats.empty() {
    return DatabaseStats(
      personsCount: 0,
      eventsCount: 0,
      analysisCount: 0,
      customEventsCount: 0,
      databaseSizeBytes: 0,
      databaseSizeMB: 0.0,
      totalRecords: 0,
    );
  }

  @override
  String toString() {
    return 'DatabaseStats('
        'persons: $personsCount, '
        'events: $eventsCount, '
        'analysis: $analysisCount, '
        'customEvents: $customEventsCount, '
        'size: ${databaseSizeMB.toStringAsFixed(2)}MB'
        ')';
  }
}

