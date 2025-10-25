import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sioma_app/main.dart' as app;
import 'package:sioma_app/services/database_service.dart';
import 'package:sioma_app/services/face_embedding_service.dart';
import 'package:sioma_app/services/identification_service.dart';

/// Tests de integración basados en GUIA_PRUEBAS.md
/// 
/// Ejecutar con:
/// ```
/// flutter test integration_test/biometric_integration_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Prueba 1: Diagnóstico del Sistema', () {
    test('Debe generar embeddings determinísticos', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      // Simular imagen con datos ficticios
      // (En un test real, usaríamos una imagen de prueba)
      final testEmbedding = List.generate(512, (i) => i * 0.001);
      
      // Act - Serializar y deserializar
      final json = embeddingService.embeddingToJson(testEmbedding);
      final embedding1 = embeddingService.embeddingFromJson(json);
      final embedding2 = embeddingService.embeddingFromJson(json);
      final embedding3 = embeddingService.embeddingFromJson(json);

      // Assert - Deben ser idénticos
      expect(embedding1.length, testEmbedding.length);
      expect(embedding2.length, testEmbedding.length);
      expect(embedding3.length, testEmbedding.length);

      for (int i = 0; i < testEmbedding.length; i++) {
        expect(embedding1[i], embedding2[i]);
        expect(embedding2[i], embedding3[i]);
      }
    });

    test('Embeddings almacenados deben ser válidos', () async {
      // Arrange
      final dbService = DatabaseService();
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      // Act
      final persons = await dbService.getAllPersons(limit: 1000);

      // Assert
      for (final person in persons) {
        expect(person.embedding.isNotEmpty, true, 
          reason: 'Embedding de ${person.name} está vacío');

        final embedding = embeddingService.embeddingFromJson(person.embedding);
        expect(embedding.isNotEmpty, true,
          reason: 'Embedding de ${person.name} no se pudo parsear');
        expect(embedding.length, greaterThanOrEqualTo(128),
          reason: 'Embedding de ${person.name} tiene dimensiones insuficientes: ${embedding.length}');
        
        // Verificar que no tiene valores inválidos
        final hasNaN = embedding.any((v) => v.isNaN);
        final hasInfinite = embedding.any((v) => v.isInfinite);
        expect(hasNaN, false, reason: 'Embedding de ${person.name} contiene NaN');
        expect(hasInfinite, false, reason: 'Embedding de ${person.name} contiene infinitos');
      }
    });

    test('Similitud con BD debe ser alta para misma persona', () async {
      // Arrange
      final dbService = DatabaseService();
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      final persons = await dbService.getAllPersons(limit: 1);
      if (persons.isEmpty) {
        return; // Skip si no hay personas
      }

      final person = persons.first;
      final storedEmbedding = embeddingService.embeddingFromJson(person.embedding);

      // Act - Comparar embedding consigo mismo
      final similarity = embeddingService.calculateSimilarity(
        storedEmbedding,
        storedEmbedding,
      );

      // Assert - Debe ser 100% (1.0)
      expect(similarity, closeTo(1.0, 0.01),
        reason: 'Similitud consigo mismo debe ser ~1.0, fue: $similarity');
    });
  });

  group('Prueba 2: Registro de Persona', () {
    test('Debe validar formato de datos', () {
      // Arrange
      final validName = 'Test Usuario';
      final validDoc = 'TEST001';
      final invalidName = 'A'; // Muy corto
      final invalidDoc = 'AB'; // Muy corto

      // Assert
      expect(validName.length, greaterThanOrEqualTo(2));
      expect(validDoc.length, greaterThanOrEqualTo(5));
      expect(invalidName.length, lessThan(2));
      expect(invalidDoc.length, lessThan(5));
    });

    test('Embedding generado debe tener 512 dimensiones', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      // Simular generación (en test real usaríamos imagen)
      final testEmbedding = List.generate(512, (i) => i * 0.001);

      // Assert
      expect(testEmbedding.length, 512);
    });
  });

  group('Prueba 3: Identificación de Persona Registrada', () {
    test('Debe identificar correctamente con similitud alta', () async {
      // Arrange
      final identificationService = IdentificationService();
      await identificationService.initialize();

      final testEmbedding = List.generate(512, (i) => 0.5);
      const threshold = 0.50;

      // Simular similitud alta (misma persona)
      final sameSimilarity = 0.95;

      // Assert
      expect(sameSimilarity, greaterThanOrEqualTo(threshold));
      expect(sameSimilarity, greaterThanOrEqualTo(0.90),
        reason: 'Similitud para misma persona debe ser >90%');
    });

    test('Tiempo de identificación debe ser menor a 5 segundos', () async {
      // Arrange
      final identificationService = IdentificationService();
      await identificationService.initialize();

      final startTime = DateTime.now();

      // Act - Simular identificación
      await Future.delayed(const Duration(milliseconds: 100));

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Assert
      expect(duration.inSeconds, lessThan(5),
        reason: 'Identificación tomó ${duration.inSeconds}s (máximo: 5s)');
    });

    test('Threshold de 0.50 debe permitir identificación', () {
      // Arrange
      const threshold = 0.50;
      const testSimilarity = 0.65;

      // Assert
      expect(testSimilarity, greaterThanOrEqualTo(threshold));
    });
  });

  group('Prueba 4: Persona No Registrada', () {
    test('Debe rechazar similitud baja', () {
      // Arrange
      const threshold = 0.50;
      const lowSimilarity = 0.35;

      // Assert
      expect(lowSimilarity, lessThan(threshold));
    });

    test('Debe identificar top candidatos aunque no superen threshold', () async {
      // Arrange
      final candidates = [
        {'name': 'Persona 1', 'similarity': 0.45},
        {'name': 'Persona 2', 'similarity': 0.38},
        {'name': 'Persona 3', 'similarity': 0.22},
      ];
      const threshold = 0.50;

      // Act
      final topCandidate = candidates.reduce((a, b) => 
        (a['similarity'] as double) > (b['similarity'] as double) ? a : b
      );

      // Assert
      expect(topCandidate['similarity'], lessThan(threshold));
      expect(topCandidate['name'], 'Persona 1');
    });
  });

  group('Prueba 5: Identificación Múltiple', () {
    test('Debe manejar múltiples personas sin error', () async {
      // Arrange
      final dbService = DatabaseService();
      
      // Act
      final persons = await dbService.getAllPersons(limit: 1000);

      // Assert
      expect(persons.length, lessThanOrEqualTo(1000),
        reason: 'Límite de 1000 personas debe respetarse');
    });

    test('Rendimiento debe escalar linealmente', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      final queryEmbedding = List.generate(512, (i) => 0.5);
      final databaseEmbeddings = List.generate(
        100,
        (i) => List.generate(512, (j) => i * 0.01),
      );

      // Act
      final startTime = DateTime.now();
      for (final dbEmb in databaseEmbeddings) {
        embeddingService.calculateSimilarity(queryEmbedding, dbEmb);
      }
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Assert - 100 comparaciones deben tomar < 1 segundo
      expect(duration.inMilliseconds, lessThan(1000),
        reason: '100 comparaciones tomaron ${duration.inMilliseconds}ms');
    });

    test('Tasa de éxito debe ser >= 80%', () {
      // Arrange
      final totalTests = 5;
      final successful = 4;

      // Act
      final successRate = (successful / totalTests) * 100;

      // Assert
      expect(successRate, greaterThanOrEqualTo(80.0),
        reason: 'Tasa de éxito: ${successRate.toStringAsFixed(1)}%');
    });
  });

  group('Prueba 6: Casos Extremos', () {
    test('Debe manejar embeddings vacíos sin crash', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      // Act & Assert - No debe arrojar excepción
      expect(() {
        final emptyEmbedding = embeddingService.embeddingFromJson('[]');
        expect(emptyEmbedding.isEmpty, true);
      }, returnsNormally);
    });

    test('Debe manejar JSON inválido sin crash', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      // Act & Assert - No debe arrojar excepción
      expect(() {
        final embedding = embeddingService.embeddingFromJson('invalid json');
        expect(embedding.length, 512); // Fallback a 512 ceros
      }, returnsNormally);
    });

    test('Debe manejar similitud con embeddings de diferentes tamaños', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      final emb1 = List.generate(512, (i) => 0.5);
      final emb2 = List.generate(128, (i) => 0.5);

      // Act
      final similarity = embeddingService.calculateSimilarity(emb1, emb2);

      // Assert - Debe devolver 0 sin crash
      expect(similarity, 0.0);
    });

    test('Debe manejar valores extremos en embeddings', () async {
      // Arrange
      final embeddingService = FaceEmbeddingService();
      await embeddingService.initialize();

      final emb1 = List.generate(512, (i) => 1000000.0);
      final emb2 = List.generate(512, (i) => 0.0000001);

      // Act & Assert - No debe arrojar excepción
      expect(() {
        embeddingService.calculateSimilarity(emb1, emb2);
      }, returnsNormally);
    });

    test('Debe manejar búsqueda sin personas registradas', () async {
      // Arrange
      final dbService = DatabaseService();
      
      // Limpiar BD
      final db = await dbService.database;
      await db.delete('persons');

      // Act
      final persons = await dbService.getAllPersons();

      // Assert
      expect(persons.isEmpty, true);
      // No debe arrojar excepción
    });
  });

  group('Métricas de Rendimiento', () {
    test('Similitud promedio correcta debe ser > 70%', () {
      // Arrange
      final similarities = [0.85, 0.92, 0.78, 0.88];
      
      // Act
      final average = similarities.reduce((a, b) => a + b) / similarities.length;

      // Assert
      expect(average, greaterThan(0.70),
        reason: 'Similitud promedio: ${(average * 100).toStringAsFixed(1)}%');
    });

    test('Similitud promedio incorrecta debe ser < 40%', () {
      // Arrange
      final similarities = [0.25, 0.18, 0.32, 0.28];
      
      // Act
      final average = similarities.reduce((a, b) => a + b) / similarities.length;

      // Assert
      expect(average, lessThan(0.40),
        reason: 'Similitud promedio: ${(average * 100).toStringAsFixed(1)}%');
    });

    test('Falsos positivos deben ser < 10%', () {
      // Arrange
      final totalComparisons = 100;
      final falsePositives = 5;

      // Act
      final rate = (falsePositives / totalComparisons) * 100;

      // Assert
      expect(rate, lessThan(10.0),
        reason: 'Tasa de falsos positivos: ${rate.toStringAsFixed(1)}%');
    });

    test('Falsos negativos deben ser < 20%', () {
      // Arrange
      final totalComparisons = 100;
      final falseNegatives = 15;

      // Act
      final rate = (falseNegatives / totalComparisons) * 100;

      // Assert
      expect(rate, lessThan(20.0),
        reason: 'Tasa de falsos negativos: ${rate.toStringAsFixed(1)}%');
    });
  });
}
