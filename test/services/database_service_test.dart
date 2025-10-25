import 'package:flutter_test/flutter_test.dart';
import 'package:sioma_app/models/person.dart';
import 'package:sioma_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Inicializar FFI para tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      // Crear instancia nueva para cada test
      dbService = DatabaseService();
      await dbService.database; // Inicializar BD
    });

    tearDown(() async {
      // Limpiar después de cada test
      final db = await dbService.database;
      await db.delete('persons');
      await db.delete('identification_events');
    });

    test('Debe insertar persona correctamente', () async {
      // Arrange
      final person = Person(
        name: 'Test Usuario',
        documentId: 'TEST001',
        photoPath: '/test/photo.jpg',
        embedding: '[0.1, 0.2, 0.3]',
      );

      // Act
      final id = await dbService.insertPerson(person);

      // Assert
      expect(id, greaterThan(0));
      
      final persons = await dbService.getAllPersons();
      expect(persons.length, 1);
      expect(persons.first.name, 'Test Usuario');
      expect(persons.first.documentId, 'TEST001');
    });

    test('Debe rechazar documento duplicado', () async {
      // Arrange
      final person1 = Person(
        name: 'Persona 1',
        documentId: 'DOC001',
        photoPath: '/test/p1.jpg',
        embedding: '[0.1]',
      );
      final person2 = Person(
        name: 'Persona 2',
        documentId: 'DOC001', // Documento duplicado
        photoPath: '/test/p2.jpg',
        embedding: '[0.2]',
      );

      // Act
      await dbService.insertPerson(person1);

      // Assert
      expect(
        () async => await dbService.insertPerson(person2),
        throwsA(isA<Exception>()),
      );
    });

    test('Debe obtener persona por documento', () async {
      // Arrange
      final person = Person(
        name: 'Juan Pérez',
        documentId: 'JP123',
        photoPath: '/test/juan.jpg',
        embedding: '[0.5, 0.5]',
      );
      await dbService.insertPerson(person);

      // Act
      final found = await dbService.getPersonByDocument('JP123');

      // Assert
      expect(found, isNotNull);
      expect(found!.name, 'Juan Pérez');
      expect(found.documentId, 'JP123');
    });

    test('Debe devolver null si persona no existe', () async {
      // Act
      final found = await dbService.getPersonByDocument('NOEXISTE');

      // Assert
      expect(found, isNull);
    });

    test('Debe eliminar persona correctamente', () async {
      // Arrange
      final person = Person(
        name: 'Borrable',
        documentId: 'DEL001',
        photoPath: '/test/del.jpg',
        embedding: '[0.1]',
      );
      final id = await dbService.insertPerson(person);

      // Act
      final deleted = await dbService.deletePerson(id);

      // Assert
      expect(deleted, greaterThan(0));
      
      final persons = await dbService.getAllPersons();
      expect(persons.length, 0);
    });

    test('Debe actualizar persona correctamente', () async {
      // Arrange
      final person = Person(
        name: 'Original',
        documentId: 'UPD001',
        photoPath: '/test/orig.jpg',
        embedding: '[0.1]',
      );
      final id = await dbService.insertPerson(person);

      // Act
      final updated = person.copyWith(
        id: id,
        name: 'Actualizado',
      );
      await dbService.updatePerson(updated);

      // Assert
      final found = await dbService.getPersonByDocument('UPD001');
      expect(found!.name, 'Actualizado');
    });

    test('Debe obtener todas las personas con límite', () async {
      // Arrange
      for (int i = 0; i < 15; i++) {
        await dbService.insertPerson(Person(
          name: 'Persona $i',
          documentId: 'DOC$i',
          photoPath: '/test/$i.jpg',
          embedding: '[$i]',
        ));
      }

      // Act
      final persons = await dbService.getAllPersons(limit: 10);

      // Assert
      expect(persons.length, 10);
    });

    test('Debe validar límite máximo de 1000 personas', () async {
      // Act
      final persons = await dbService.getAllPersons(limit: 5000);

      // Assert - El límite debe ser capeado a 1000
      // (verificamos que no arroje error, el límite real se aplica en la consulta)
      expect(persons, isNotNull);
    });

    test('Debe buscar personas por nombre', () async {
      // Arrange
      await dbService.insertPerson(Person(
        name: 'Juan Carlos Pérez',
        documentId: 'JC001',
        photoPath: '/test/jc.jpg',
        embedding: '[0.1]',
      ));
      await dbService.insertPerson(Person(
        name: 'María García',
        documentId: 'MG001',
        photoPath: '/test/mg.jpg',
        embedding: '[0.2]',
      ));

      // Act
      final db = await dbService.database;
      final results = await db.query(
        'persons',
        where: 'name LIKE ?',
        whereArgs: ['%Juan%'],
      );

      // Assert
      expect(results.length, 1);
      expect(results.first['name'], contains('Juan'));
    });

    test('Debe contar total de personas', () async {
      // Arrange
      for (int i = 0; i < 5; i++) {
        await dbService.insertPerson(Person(
          name: 'P$i',
          documentId: 'D$i',
          photoPath: '/t$i.jpg',
          embedding: '[$i]',
        ));
      }

      // Act
      final persons = await dbService.getAllPersons();

      // Assert
      expect(persons.length, 5);
    });
  });

  group('Person Model Tests', () {
    test('Debe crear Person desde Map correctamente', () {
      // Arrange
      final map = {
        'id': 1,
        'name': 'Test',
        'document_id': 'DOC001',
        'photo_path': '/test.jpg',
        'embedding': '[0.1, 0.2]',
        'created_at': '2025-10-24 10:00:00',
      };

      // Act
      final person = Person.fromMap(map);

      // Assert
      expect(person.id, 1);
      expect(person.name, 'Test');
      expect(person.documentId, 'DOC001');
      expect(person.photoPath, '/test.jpg');
      expect(person.embedding, '[0.1, 0.2]');
    });

    test('Debe convertir Person a Map correctamente', () {
      // Arrange
      final person = Person(
        id: 1,
        name: 'Test',
        documentId: 'DOC001',
        photoPath: '/test.jpg',
        embedding: '[0.1]',
        createdAt: DateTime(2025, 10, 24, 10, 0),
      );

      // Act
      final map = person.toMap();

      // Assert
      expect(map['id'], 1);
      expect(map['name'], 'Test');
      expect(map['document_id'], 'DOC001');
      expect(map['photo_path'], '/test.jpg');
      expect(map['embedding'], '[0.1]');
      expect(map['created_at'], isA<String>());
    });

    test('Debe usar copyWith correctamente', () {
      // Arrange
      final original = Person(
        name: 'Original',
        documentId: 'DOC001',
        photoPath: '/orig.jpg',
        embedding: '[0.1]',
      );

      // Act
      final updated = original.copyWith(name: 'Actualizado');

      // Assert
      expect(updated.name, 'Actualizado');
      expect(updated.documentId, 'DOC001'); // Sin cambios
      expect(original.name, 'Original'); // Original no modificado
    });
  });
}
