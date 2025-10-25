import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sioma_app/main.dart' as app;
import 'package:sioma_app/services/database_service.dart';
import 'package:sioma_app/models/person.dart';
import 'package:sioma_app/models/custom_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Genera un embedding JSON válido con 256 dimensiones
String _embeddingJson256() {
  final values = List<double>.generate(256, (i) => (i % 10 + 1) / 100.0);
  return '[${values.map((v) => v.toStringAsFixed(2)).join(', ')}]';
}

void main() {
  group('SIOMA Integration Tests', () {
    late DatabaseService databaseService;
    
    setUpAll(() async {
      // Inicializar la base de datos de pruebas (sqflite FFI en entorno de test)
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      databaseService = DatabaseService();
    });
    
    tearDownAll(() async {
      // Limpiar la base de datos después de las pruebas
      try {
        await databaseService.deleteDatabase();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    testWidgets('App Navigation Test', (WidgetTester tester) async {
      // Construir la aplicación
      app.main();
      // Evitar esperar a que la app "se asiente" completamente ya que hay loops periódicos
      await tester.pump(const Duration(milliseconds: 500));

      // Verificar que la navegación principal se carga (NavigationBar presente)
      expect(find.byType(NavigationBar), findsOneWidget);

  // Verificar que algunos destinos clave existan por etiqueta
  expect(find.text('Registrar'), findsWidgets);
  expect(find.text('Eventos'), findsWidgets);
    });

    test('Database Custom Events Operations', () async {
      // Insertar una persona de prueba
      final testPerson = Person(
        name: 'Juan Pérez',
        documentId: '12345678',
        photoPath: '/path/to/photo.jpg',
        embedding: _embeddingJson256(),
        createdAt: DateTime.now(),
      );
      
      final personId = await databaseService.insertPerson(testPerson);
      expect(personId, greaterThan(0));

      // Crear un evento de entrada
      final entryEvent = CustomEvent.createEntryEvent(
        personId: personId,
        personName: testPerson.name,
        personDocument: testPerson.documentId,
        location: 'oficina_principal',
        notes: 'Entrada de prueba',
      );

      // Insertar el evento
      final eventId = await databaseService.insertCustomEvent(entryEvent);
      expect(eventId, greaterThan(0));

      // Verificar que el evento se insertó correctamente
      final events = await databaseService.getAllCustomEvents();
      expect(events, isNotEmpty);
      expect(events.first.eventType, equals('entrada'));
      expect(events.first.personName, equals(testPerson.name));

      // Crear un evento de salida
      final exitEvent = CustomEvent.createExitEvent(
        personId: personId,
        personName: testPerson.name,
        personDocument: testPerson.documentId,
        location: 'oficina_principal',
        notes: 'Salida de prueba',
      );

      await databaseService.insertCustomEvent(exitEvent);

      // Verificar eventos por tipo
      final entryEvents = await databaseService.getCustomEventsByType('entrada');
      expect(entryEvents, hasLength(1));

      final exitEvents = await databaseService.getCustomEventsByType('salida');
      expect(exitEvents, hasLength(1));

      // Verificar eventos por persona
      final personEvents = await databaseService.getCustomEventsByPerson(personId);
      expect(personEvents, hasLength(2));

      // Verificar estadísticas
      final stats = await databaseService.getCustomEventsStatistics();
      expect(stats['total_events'], equals(2));
      expect(stats['events_by_type']['entrada'], equals(1));
      expect(stats['events_by_type']['salida'], equals(1));
    });

    test('Database Version Upgrade Test', () async {
      // Verificar que todas las tablas existen
      final db = await databaseService.database;
      
      // Verificar tabla de personas
      final personsTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='persons'"
      );
      expect(personsTables, isNotEmpty);
      
      // Verificar tabla de eventos de identificación
      final identificationTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='identification_events'"
      );
      expect(identificationTables, isNotEmpty);
      
      // Verificar tabla de eventos de análisis (v2)
      final analysisTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='analysis_events'"
      );
      expect(analysisTables, isNotEmpty);
      
      // Verificar tabla de eventos personalizados (v3)
      final customEventsTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='custom_events'"
      );
      expect(customEventsTables, isNotEmpty);
      
      // Verificar índices
      final indices = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index'"
      );
      expect(indices.length, greaterThan(5)); // Debe tener al menos 6 índices
    });

    test('Custom Events Date Range Filter', () async {
      // Limpiar eventos existentes para esta prueba
      final allEvents = await databaseService.getAllCustomEvents();
      for (final event in allEvents) {
        await databaseService.deleteCustomEvent(event.id!);
      }

      // Insertar una persona de prueba
      final testPerson = Person(
        name: 'Ana García',
        documentId: '87654321',
        photoPath: '/path/to/photo2.jpg',
        embedding: _embeddingJson256(),
        createdAt: DateTime.now(),
      );
      
      final personId = await databaseService.insertPerson(testPerson);

      // Crear eventos con diferentes fechas
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final today = DateTime.now();
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      // Evento de ayer
      final yesterdayEvent = CustomEvent(
        eventType: 'entrada',
        location: 'oficina_principal',
        personId: personId,
        personName: testPerson.name,
        personDocument: testPerson.documentId,
        timestamp: yesterday,
      );

      // Evento de hoy
      final todayEvent = CustomEvent(
        eventType: 'salida',
        location: 'oficina_principal',
        personId: personId,
        personName: testPerson.name,
        personDocument: testPerson.documentId,
        timestamp: today,
      );

      await databaseService.insertCustomEvent(yesterdayEvent);
      await databaseService.insertCustomEvent(todayEvent);

      // Filtrar por rango de fechas (solo hoy)
      final startOfToday = DateTime(today.year, today.month, today.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));
      
      final todaysEvents = await databaseService.getCustomEventsByDateRange(
        startOfToday,
        endOfToday,
      );

      expect(todaysEvents, hasLength(1));
      expect(todaysEvents.first.eventType, equals('salida'));

      // Filtrar eventos de entrada en los últimos 2 días
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final entryEventsInRange = await databaseService.getCustomEventsByDateRange(
        twoDaysAgo,
        DateTime.now().add(const Duration(hours: 1)),
        eventType: 'entrada',
      );

      expect(entryEventsInRange, hasLength(1));
      expect(entryEventsInRange.first.eventType, equals('entrada'));
    });
  });
}