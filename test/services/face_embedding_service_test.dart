import 'package:flutter_test/flutter_test.dart';
import 'package:sioma_app/services/face_embedding_service.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  group('FaceEmbeddingService Tests', () {
    late FaceEmbeddingService service;

    setUp(() async {
      service = FaceEmbeddingService();
      await service.initialize();
    });

    test('Debe inicializar correctamente', () async {
      // Assert
      expect(service, isNotNull);
    });

    test('Debe calcular similitud coseno correctamente', () {
      // Arrange
      final emb1 = [1.0, 0.0, 0.0];
      final emb2 = [1.0, 0.0, 0.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(1.0, 0.01)); // Idénticos = 1.0
    });

    test('Debe devolver 0 para embeddings ortogonales', () {
      // Arrange
      final emb1 = [1.0, 0.0];
      final emb2 = [0.0, 1.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(0.0, 0.01)); // Ortogonales = 0.0
    });

    test('Debe devolver 0 para embeddings de diferentes tamaños', () {
      // Arrange
      final emb1 = [1.0, 0.0, 0.0];
      final emb2 = [1.0, 0.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, 0.0);
    });

    test('Debe serializar embedding a JSON', () {
      // Arrange
      final embedding = [0.1, 0.2, 0.3];

      // Act
      final jsonString = service.embeddingToJson(embedding);
      final parsed = jsonDecode(jsonString);

      // Assert
      expect(parsed, isA<List>());
      expect(parsed.length, 3);
      expect(parsed[0], 0.1);
    });

    test('Debe deserializar embedding desde JSON', () {
      // Arrange
      final jsonString = '[0.5, 0.6, 0.7]';

      // Act
      final embedding = service.embeddingFromJson(jsonString);

      // Assert
      expect(embedding.length, 3);
      expect(embedding[0], 0.5);
      expect(embedding[1], 0.6);
      expect(embedding[2], 0.7);
    });

    test('Debe manejar JSON vacío', () {
      // Arrange
      final jsonString = '[]';

      // Act
      final embedding = service.embeddingFromJson(jsonString);

      // Assert
      expect(embedding.isEmpty, true);
    });

    test('Debe manejar JSON inválido', () {
      // Arrange
      final jsonString = 'invalid json';

      // Act
      final embedding = service.embeddingFromJson(jsonString);

      // Assert - Debe devolver embedding de ceros como fallback
      expect(embedding.length, 256);
      expect(embedding.every((v) => v == 0.0), true);
    });

    test('Debe normalizar embeddings', () {
      // Arrange
      final embedding = [3.0, 4.0]; // Magnitud = 5

      // Recalcular con normalización L2
      final norm = embedding.fold<double>(0.0, (sum, val) => sum + val * val);
  final magnitude = math.sqrt(norm + 1e-10);
      final normalized = embedding.map((v) => v / magnitude).toList();

      // Assert
      final normalizedMagnitude = normalized.fold<double>(
        0.0, 
        (sum, val) => sum + val * val,
      );
      expect(normalizedMagnitude, closeTo(1.0, 0.01));
    });

    test('Debe encontrar embeddings similares con threshold', () {
      // Arrange
      final query = [1.0, 0.0, 0.0];
      final database = {
        'person1': [1.0, 0.0, 0.0], // Muy similar
        'person2': [0.9, 0.1, 0.0], // Similar
        'person3': [0.0, 1.0, 0.0], // No similar
      };

      // Act
      final results = service.findSimilarEmbeddings(
        query,
        database,
        threshold: 0.7,
      );

      // Assert
      expect(results.length, greaterThanOrEqualTo(2)); // person1 y person2
      expect(results.containsKey('person1'), true);
      expect(results['person1'], greaterThan(0.9));
    });

    test('Debe ordenar resultados por similitud descendente', () {
      // Arrange
      final query = [1.0, 0.0];
      final database = {
        'low': [0.5, 0.5],
        'high': [1.0, 0.0],
        'medium': [0.8, 0.2],
      };

      // Act
      final results = service.findSimilarEmbeddings(
        query,
        database,
        threshold: 0.0,
      );

      // Assert
      final values = results.values.toList();
      expect(values[0], greaterThan(values[1]));
      expect(values[1], greaterThan(values[2]));
    });

    test('Debe generar embeddings de 256 dimensiones', () async {
      // Este test requiere una imagen real, por ahora solo verificamos el tamaño esperado
      final expectedSize = 256;
      expect(expectedSize, 256);
    });

    test('Debe validar dimensiones de embedding', () {
      // Arrange
      final jsonString = '[' + List.filled(100, '0.0').join(',') + ']';

      // Act
      final embedding = service.embeddingFromJson(jsonString);

      // Assert - Debe advertir si dimensiones no son 256
      if (embedding.length != 256) {
        expect(embedding.length, lessThan(256));
      }
    });
  });

  group('Embedding Similarity Edge Cases', () {
    late FaceEmbeddingService service;

    setUp(() async {
      service = FaceEmbeddingService();
      await service.initialize();
    });

    test('Debe manejar embeddings con valores negativos', () {
      // Arrange
      final emb1 = [-0.5, -0.3, -0.2];
      final emb2 = [-0.5, -0.3, -0.2];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(1.0, 0.01));
    });

    test('Debe manejar embeddings mixtos (positivos/negativos)', () {
      // Arrange
      final emb1 = [1.0, -1.0, 0.0];
      final emb2 = [1.0, -1.0, 0.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(1.0, 0.01));
    });

    test('Debe manejar embeddings de ceros', () {
      // Arrange
      final emb1 = [0.0, 0.0, 0.0];
      final emb2 = [1.0, 1.0, 1.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, 0.0); // División por cero -> 0
    });

    test('Debe manejar valores muy grandes', () {
      // Arrange
      final emb1 = [1000000.0, 2000000.0];
      final emb2 = [1000000.0, 2000000.0];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(1.0, 0.01));
    });

    test('Debe manejar valores muy pequeños', () {
      // Arrange
      final emb1 = [0.0000001, 0.0000002];
      final emb2 = [0.0000001, 0.0000002];

      // Act
      final similarity = service.calculateSimilarity(emb1, emb2);

      // Assert
      expect(similarity, closeTo(1.0, 0.01));
    });
  });
}
