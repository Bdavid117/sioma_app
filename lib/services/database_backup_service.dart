import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/person.dart';
import '../models/custom_event.dart';
import '../services/database_service.dart';
import '../utils/app_logger.dart';

/// Servicio para backup y restauración de base de datos
/// Permite exportar/importar datos en formato JSON local
class DatabaseBackupService {
  final DatabaseService _databaseService;

  DatabaseBackupService(this._databaseService);

  /// Exporta toda la base de datos a un archivo JSON
  Future<File> exportDatabase() async {
    try {
      DatabaseLogger.info('📦 Iniciando exportación de base de datos...');

      // 1. Obtener todos los datos
      final persons = await _databaseService.getAllPersons();
      final events = await _databaseService.getAllCustomEvents();

      DatabaseLogger.info('Datos a exportar: ${persons.length} personas, ${events.length} eventos');

      // 2. Crear estructura de backup
      final backup = {
        'version': 3,
        'timestamp': DateTime.now().toIso8601String(),
        'exportedBy': 'SIOMA App',
        'statistics': {
          'totalPersons': persons.length,
          'totalEvents': events.length,
        },
        'persons': persons.map((p) => _personToJson(p)).toList(),
        'events': events.map((e) => _eventToJson(e)).toList(),
      };

      // 3. Convertir a JSON
      final jsonString = JsonEncoder.withIndent('  ').convert(backup);

      // 4. Guardar en archivo
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/sioma_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'sioma_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');
      
      await file.writeAsString(jsonString);

      final fileSizeMB = (await file.length()) / (1024 * 1024);
      DatabaseLogger.info('✅ Backup creado exitosamente: $fileName (${fileSizeMB.toStringAsFixed(2)} MB)');

      return file;
    } catch (e, stackTrace) {
      DatabaseLogger.error('Error al exportar base de datos', e, stackTrace);
      rethrow;
    }
  }

  /// Importa base de datos desde un archivo JSON
  /// ADVERTENCIA: Esto reemplazará todos los datos actuales
  Future<BackupImportResult> importDatabase(File backupFile) async {
    try {
      DatabaseLogger.info('📥 Iniciando importación de backup: ${backupFile.path}');

      // 1. Leer archivo
      if (!await backupFile.exists()) {
        throw Exception('Archivo de backup no existe');
      }

      final jsonString = await backupFile.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      // 2. Validar estructura
      final validation = _validateBackupStructure(backup);
      if (!validation.isValid) {
        DatabaseLogger.error('Estructura de backup inválida', validation.error);
        return BackupImportResult(
          success: false,
          message: validation.error ?? 'Estructura inválida',
        );
      }

      // 3. Contar elementos a importar
      final personsData = backup['persons'] as List<dynamic>;
      final eventsData = backup['events'] as List<dynamic>;

      DatabaseLogger.info('Importando ${personsData.length} personas y ${eventsData.length} eventos...');

      // 4. Limpiar base de datos actual (PELIGROSO)
      // await _databaseService.clearAllData(); // Implementar si es necesario

      // 5. Importar personas
      int personsImported = 0;
      for (final personData in personsData) {
        try {
          final person = _jsonToPerson(personData as Map<String, dynamic>);
          await _databaseService.insertPerson(person);
          personsImported++;
        } catch (e) {
          DatabaseLogger.warning('Error al importar persona: $e');
        }
      }

      // 6. Importar eventos
      int eventsImported = 0;
      for (final eventData in eventsData) {
        try {
          final event = _jsonToEvent(eventData as Map<String, dynamic>);
          await _databaseService.insertCustomEvent(event);
          eventsImported++;
        } catch (e) {
          DatabaseLogger.warning('Error al importar evento: $e');
        }
      }

      DatabaseLogger.info(
        '✅ Importación completada: $personsImported personas, $eventsImported eventos'
      );

      return BackupImportResult(
        success: true,
        message: 'Importación exitosa',
        personsImported: personsImported,
        eventsImported: eventsImported,
      );

    } catch (e, stackTrace) {
      DatabaseLogger.error('Error al importar backup', e, stackTrace);
      return BackupImportResult(
        success: false,
        message: 'Error: $e',
      );
    }
  }

  /// Lista todos los backups disponibles
  Future<List<File>> listBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/sioma_backups');
      
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      final backupFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      backupFiles.sort((a, b) => b.path.compareTo(a.path)); // Más recientes primero

      return backupFiles;
    } catch (e) {
      DatabaseLogger.error('Error al listar backups', e);
      return [];
    }
  }

  /// Elimina un backup específico
  Future<void> deleteBackup(File backupFile) async {
    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
        DatabaseLogger.info('🗑️ Backup eliminado: ${backupFile.path}');
      }
    } catch (e) {
      DatabaseLogger.error('Error al eliminar backup', e);
      rethrow;
    }
  }

  /// Valida la estructura de un archivo de backup
  BackupValidation _validateBackupStructure(Map<String, dynamic> backup) {
    try {
      // Validar campos requeridos
      if (!backup.containsKey('version')) {
        return BackupValidation(false, 'Falta campo "version"');
      }
      if (!backup.containsKey('persons')) {
        return BackupValidation(false, 'Falta campo "persons"');
      }
      if (!backup.containsKey('events')) {
        return BackupValidation(false, 'Falta campo "events"');
      }

      // Validar tipos
      if (backup['persons'] is! List) {
        return BackupValidation(false, 'Campo "persons" debe ser una lista');
      }
      if (backup['events'] is! List) {
        return BackupValidation(false, 'Campo "events" debe ser una lista');
      }

      return BackupValidation(true, null);
    } catch (e) {
      return BackupValidation(false, 'Error de validación: $e');
    }
  }

  /// Convierte Person a JSON
  Map<String, dynamic> _personToJson(Person person) {
    return {
      'id': person.id,
      'name': person.name,
      'documentId': person.documentId,
      'embedding': person.embedding, // Ya es un String
      'photoPath': person.photoPath,
      'createdAt': person.createdAt.toIso8601String(),
    };
  }

  /// Convierte JSON a Person
  Person _jsonToPerson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as int?,
      name: json['name'] as String,
      documentId: json['documentId'] as String,
      embedding: json['embedding'] as String, // Ya es un String
      photoPath: json['photoPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convierte CustomEvent a JSON
  Map<String, dynamic> _eventToJson(CustomEvent event) {
    return {
      'id': event.id,
      'personId': event.personId,
      'personName': event.personName,
      'personDocument': event.personDocument,
      'eventType': event.eventType,
      'timestamp': event.timestamp.toIso8601String(),
      'confidence': event.confidence,
      'location': event.location,
      'notes': event.notes,
    };
  }

  /// Convierte JSON a CustomEvent
  CustomEvent _jsonToEvent(Map<String, dynamic> json) {
    return CustomEvent(
      id: json['id'] as int?,
      personId: json['personId'] as int,
      personName: json['personName'] as String,
      personDocument: json['personDocument'] as String,
      eventType: json['eventType'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: json['confidence'] as double?,
      location: json['location'] as String? ?? 'Desconocido',
      notes: json['notes'] as String?,
    );
  }
}

/// Resultado de la validación de backup
class BackupValidation {
  final bool isValid;
  final String? error;

  BackupValidation(this.isValid, this.error);
}

/// Resultado de la importación de backup
class BackupImportResult {
  final bool success;
  final String message;
  final int? personsImported;
  final int? eventsImported;

  BackupImportResult({
    required this.success,
    required this.message,
    this.personsImported,
    this.eventsImported,
  });

  @override
  String toString() {
    if (!success) return 'Import Failed: $message';
    return 'Import Success: $personsImported personas, $eventsImported eventos';
  }
}
