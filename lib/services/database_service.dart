import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/person.dart';
import '../models/identification_event.dart';
import '../utils/validation_utils.dart';
import 'dart:developer' as developer;

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

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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

    // Índices para mejorar el rendimiento
    await db.execute(
      'CREATE INDEX idx_document_id ON persons(document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_timestamp ON identification_events(timestamp DESC)',
    );
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
        createdAt: person.createdAt,
      );

      final db = await database;
      final id = await db.insert('persons', validatedPerson.toMap());

      developer.log('Person inserted successfully: ID=$id, Document=${validatedPerson.documentId}');
      return id;
    } on SiomaValidationException {
      rethrow;
    } on SiomaDatabaseException {
      rethrow;
    } catch (e) {
      developer.log('Error inserting person: $e', level: 1000);
      throw SiomaDatabaseException('Error al insertar persona en la base de datos', e.toString());
    }
  }

  /// Obtiene todas las personas con límites de seguridad
  Future<List<Person>> getAllPersons({int? limit, int? offset}) async {
    try {
      final db = await database;

      // Aplicar límite de seguridad (máximo 1000 registros por consulta)
      final safeLimit = limit != null ? (limit > 1000 ? 1000 : limit) : 100;
      final safeOffset = offset ?? 0;

      final List<Map<String, dynamic>> maps = await db.query(
        'persons',
        orderBy: 'created_at DESC',
        limit: safeLimit,
        offset: safeOffset,
      );

      return List.generate(maps.length, (i) => Person.fromMap(maps[i]));
    } catch (e) {
      developer.log('Error getting all persons: $e', level: 1000);
      throw SiomaDatabaseException('Error al obtener la lista de personas', e.toString());
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
        developer.log('Invalid document ID provided: $documentId');
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
      developer.log('Error getting person by document: $e', level: 1000);
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
  Future<int> getPersonsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM persons');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== OPERACIONES EVENTS ====================

  /// Inserta un nuevo evento de identificación
  Future<int> insertIdentificationEvent(IdentificationEvent event) async {
    final db = await database;
    return await db.insert('identification_events', event.toMap());
  }

  /// Obtiene todos los eventos de identificación
  Future<List<IdentificationEvent>> getAllEvents({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'identification_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
  }

  /// Obtiene eventos por persona
  Future<List<IdentificationEvent>> getEventsByPerson(int personId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'identification_events',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => IdentificationEvent.fromMap(maps[i]));
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

