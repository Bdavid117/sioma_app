import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../services/database_service.dart';
import '../services/face_embedding_service.dart';
import '../models/person.dart';

/// Herramienta de diagnóstico para problemas de reconocimiento biométrico
class BiometricDiagnostic {
  final DatabaseService _db = DatabaseService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();

  /// Ejecuta diagnóstico completo del sistema
  Future<void> runFullDiagnostic() async {
    print('\n═══════════════════════════════════════════════════════════');
    print('🔬 DIAGNÓSTICO BIOMÉTRICO SIOMA');
    print('═══════════════════════════════════════════════════════════\n');

    await _embeddingService.initialize();

    // 1. Verificar personas en BD
    await _checkDatabasePersons();
    
    // 2. Validar embeddings almacenados
    await _validateStoredEmbeddings();
    
    // 3. Probar generación de embeddings determinísticos
    await _testDeterministicEmbeddings();
    
    // 4. Simular identificación real
    await _simulateIdentification();
    
    print('\n═══════════════════════════════════════════════════════════');
    print('✅ Diagnóstico completado');
    print('═══════════════════════════════════════════════════════════\n');
  }

  /// Verifica personas en la base de datos
  Future<void> _checkDatabasePersons() async {
    print('📊 PASO 1: Verificando base de datos');
    print('─────────────────────────────────────');
    
    try {
      final persons = await _db.getAllPersons(limit: 1000);
      print('✅ Personas registradas: ${persons.length}');
      
      if (persons.isEmpty) {
        print('⚠️  No hay personas registradas en la BD');
        print('   Recomendación: Registra al menos una persona primero\n');
        return;
      }

      print('\n👥 Listado de personas:');
      for (int i = 0; i < persons.length; i++) {
        final person = persons[i];
        print('   ${i + 1}. ${person.name} (${person.documentId})');
        print('      - Foto: ${person.photoPath}');
        print('      - Registrado: ${person.createdAt}');
      }
      print('');
    } catch (e) {
      print('❌ Error accediendo a la BD: $e\n');
    }
  }

  /// Valida embeddings almacenados
  Future<void> _validateStoredEmbeddings() async {
    print('🧬 PASO 2: Validando embeddings almacenados');
    print('─────────────────────────────────────────────');
    
    try {
      final persons = await _db.getAllPersons(limit: 1000);
      
      if (persons.isEmpty) {
        print('⚠️  No hay personas para validar\n');
        return;
      }

      int validEmbeddings = 0;
      int invalidEmbeddings = 0;
      Map<int, List<String>> issuesByPerson = {};

      for (final person in persons) {
        List<String> issues = [];
        
        // Verificar embedding no vacío
        if (person.embedding.isEmpty) {
          issues.add('Embedding vacío');
          invalidEmbeddings++;
          continue;
        }

        try {
          // Intentar parsear
          final embeddingData = jsonDecode(person.embedding);
          
          if (embeddingData is! List) {
            issues.add('Embedding no es lista');
            invalidEmbeddings++;
            continue;
          }

          final embeddingList = (embeddingData as List).map((e) => (e as num).toDouble()).toList();
          
          // Verificar dimensiones
          if (embeddingList.isEmpty) {
            issues.add('Embedding con 0 dimensiones');
          } else if (embeddingList.length < 256) {
            issues.add('Dimensiones insuficientes: ${embeddingList.length} (mínimo 256)');
          } else if (embeddingList.length != 512) {
            issues.add('Dimensiones no estándar: ${embeddingList.length} (esperado 512)');
          }

          // Verificar valores
          bool hasNaN = embeddingList.any((v) => v.isNaN);
          bool hasInfinite = embeddingList.any((v) => v.isInfinite);
          bool allZeros = embeddingList.every((v) => v == 0.0);
          
          if (hasNaN) issues.add('Contiene NaN');
          if (hasInfinite) issues.add('Contiene infinitos');
          if (allZeros) issues.add('Todos los valores son 0');

          // Estadísticas del embedding
          final mean = embeddingList.reduce((a, b) => a + b) / embeddingList.length;
          final max = embeddingList.reduce((a, b) => a > b ? a : b);
          final min = embeddingList.reduce((a, b) => a < b ? a : b);

          if (issues.isEmpty) {
            validEmbeddings++;
            print('✅ ${person.name}:');
            print('   - Dimensiones: ${embeddingList.length}');
            print('   - Rango: [${min.toStringAsFixed(3)}, ${max.toStringAsFixed(3)}]');
            print('   - Media: ${mean.toStringAsFixed(3)}');
          } else {
            invalidEmbeddings++;
            issuesByPerson[person.id!] = issues;
          }

        } catch (e) {
          issues.add('Error al parsear: $e');
          invalidEmbeddings++;
          issuesByPerson[person.id!] = issues;
        }
      }

      print('\n📈 Resumen de validación:');
      print('   ✅ Embeddings válidos: $validEmbeddings');
      print('   ❌ Embeddings inválidos: $invalidEmbeddings');

      if (issuesByPerson.isNotEmpty) {
        print('\n⚠️  Problemas encontrados:');
        for (final entry in issuesByPerson.entries) {
          final person = persons.firstWhere((p) => p.id == entry.key);
          print('   ${person.name}:');
          for (final issue in entry.value) {
            print('     - $issue');
          }
        }
      }
      print('');
    } catch (e) {
      print('❌ Error validando embeddings: $e\n');
    }
  }

  /// Prueba generación de embeddings determinísticos
  Future<void> _testDeterministicEmbeddings() async {
    print('🔬 PASO 3: Probando embeddings determinísticos');
    print('───────────────────────────────────────────────');
    
    try {
      final persons = await _db.getAllPersons(limit: 1000);
      
      if (persons.isEmpty) {
        print('⚠️  No hay personas para probar\n');
        return;
      }

      // Tomar la primera persona con foto
      final testPerson = persons.firstWhere(
        (p) => p.photoPath.isNotEmpty && File(p.photoPath).existsSync(),
        orElse: () => persons.first,
      );

      if (testPerson.photoPath.isEmpty || !File(testPerson.photoPath).existsSync()) {
        print('⚠️  Foto no encontrada: ${testPerson.photoPath}\n');
        return;
      }

      print('🧪 Persona de prueba: ${testPerson.name}');
      print('   Foto: ${testPerson.photoPath}\n');

      // Generar embedding 3 veces de la misma imagen
      print('   Generando 3 embeddings de la misma imagen...');
      final embedding1 = await _embeddingService.generateEmbedding(testPerson.photoPath);
      final embedding2 = await _embeddingService.generateEmbedding(testPerson.photoPath);
      final embedding3 = await _embeddingService.generateEmbedding(testPerson.photoPath);

      if (embedding1 == null || embedding2 == null || embedding3 == null) {
        print('❌ Error generando embeddings\n');
        return;
      }

      // Comparar embeddings
      bool identical12 = _areEmbeddingsIdentical(embedding1, embedding2);
      bool identical23 = _areEmbeddingsIdentical(embedding2, embedding3);
      bool identical13 = _areEmbeddingsIdentical(embedding1, embedding3);

      if (identical12 && identical23 && identical13) {
        print('   ✅ Embeddings IDÉNTICOS (determinístico)');
      } else {
        print('   ❌ Embeddings DIFERENTES (NO determinístico)');
        print('      Esto causará fallos de reconocimiento');
        
        final similarity12 = _embeddingService.calculateSimilarity(embedding1, embedding2);
        final similarity23 = _embeddingService.calculateSimilarity(embedding2, embedding3);
        final similarity13 = _embeddingService.calculateSimilarity(embedding1, embedding3);
        
        print('      Similitud 1-2: ${(similarity12 * 100).toStringAsFixed(2)}%');
        print('      Similitud 2-3: ${(similarity23 * 100).toStringAsFixed(2)}%');
        print('      Similitud 1-3: ${(similarity13 * 100).toStringAsFixed(2)}%');
      }

      // Comparar con embedding almacenado
      print('\n   Comparando con embedding almacenado en BD...');
      final storedEmbedding = _parseEmbedding(testPerson.embedding);
      if (storedEmbedding != null) {
        final similarityWithStored = _embeddingService.calculateSimilarity(embedding1, storedEmbedding);
        print('   Similitud con BD: ${(similarityWithStored * 100).toStringAsFixed(2)}%');
        
        if (similarityWithStored < 0.65) {
          print('   ⚠️  PROBLEMA: Similitud muy baja con BD');
          print('      Recomendación: Re-registrar esta persona');
        } else if (similarityWithStored < 0.90) {
          print('   ⚠️  Similitud moderada (puede haber problemas)');
        } else {
          print('   ✅ Similitud alta (sistema funcionando)');
        }
      }

      print('');
    } catch (e) {
      print('❌ Error en prueba determinística: $e\n');
    }
  }

  /// Simula proceso de identificación
  Future<void> _simulateIdentification() async {
    print('🎯 PASO 4: Simulando identificación 1:N');
    print('─────────────────────────────────────────');
    
    try {
      final persons = await _db.getAllPersons(limit: 1000);
      
      if (persons.length < 2) {
        print('⚠️  Se necesitan al menos 2 personas registradas\n');
        return;
      }

      // Tomar primera persona como "consulta"
      final queryPerson = persons.first;
      if (queryPerson.photoPath.isEmpty || !File(queryPerson.photoPath).existsSync()) {
        print('⚠️  Foto no encontrada para ${queryPerson.name}\n');
        return;
      }

      print('🔍 Buscando: ${queryPerson.name}');
      print('   Foto: ${queryPerson.photoPath}\n');

      // Generar embedding de consulta
      final queryEmbedding = await _embeddingService.generateEmbedding(queryPerson.photoPath);
      if (queryEmbedding == null) {
        print('❌ Error generando embedding de consulta\n');
        return;
      }

      print('📊 Comparando contra ${persons.length} personas:\n');

      // Comparar contra todos
      List<Map<String, dynamic>> results = [];
      for (final person in persons) {
        final storedEmbedding = _parseEmbedding(person.embedding);
        if (storedEmbedding == null) continue;

        final similarity = _embeddingService.calculateSimilarity(queryEmbedding, storedEmbedding);
        results.add({
          'person': person,
          'similarity': similarity,
        });
      }

      // Ordenar por similitud
      results.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

      // Mostrar top 5
      print('   🏆 Top 5 candidatos:');
      for (int i = 0; i < results.length && i < 5; i++) {
        final result = results[i];
        final person = result['person'] as Person;
        final similarity = result['similarity'] as double;
        final isMatch = person.id == queryPerson.id;
        final icon = isMatch ? '✅' : '  ';
        final threshold65 = similarity >= 0.65 ? '✓' : '✗';
        final threshold50 = similarity >= 0.50 ? '✓' : '✗';
        
        print('   $icon ${i + 1}. ${person.name}: ${(similarity * 100).toStringAsFixed(2)}% '
              '[T65:$threshold65 T50:$threshold50]');
      }

      // Verificar si encontró correctamente
      final bestMatch = results.first['person'] as Person;
      final bestSimilarity = results.first['similarity'] as double;
      
      print('\n📈 Análisis:');
      if (bestMatch.id == queryPerson.id) {
        print('   ✅ Identificación CORRECTA');
        print('   Similitud: ${(bestSimilarity * 100).toStringAsFixed(2)}%');
        
        if (bestSimilarity >= 0.65) {
          print('   ✅ Supera threshold 0.65 (OK)');
        } else if (bestSimilarity >= 0.50) {
          print('   ⚠️  Por debajo de threshold 0.65');
          print('      Recomendación: Reducir threshold a 0.50-0.55');
        } else {
          print('   ❌ Similitud muy baja (< 0.50)');
          print('      Recomendación: Re-registrar persona');
        }
      } else {
        print('   ❌ Identificación INCORRECTA');
        print('   Identificó como: ${bestMatch.name}');
        print('   Debería ser: ${queryPerson.name}');
        
        // Buscar la persona correcta en los resultados
        final correctMatch = results.firstWhere(
          (r) => (r['person'] as Person).id == queryPerson.id,
          orElse: () => {},
        );
        
        if (correctMatch.isNotEmpty) {
          final correctSimilarity = correctMatch['similarity'] as double;
          print('   Similitud con persona correcta: ${(correctSimilarity * 100).toStringAsFixed(2)}%');
        }
      }

      print('');
    } catch (e) {
      print('❌ Error en simulación: $e\n');
    }
  }

  /// Verifica si dos embeddings son idénticos
  bool _areEmbeddingsIdentical(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) return false;
    
    for (int i = 0; i < emb1.length; i++) {
      if (emb1[i] != emb2[i]) return false;
    }
    
    return true;
  }

  /// Parsea embedding desde JSON
  List<double>? _parseEmbedding(String jsonStr) {
    try {
      if (jsonStr.isEmpty) return null;
      final data = jsonDecode(jsonStr);
      if (data is! List) return null;
      return data.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      return null;
    }
  }
}

/// Ejecutar diagnóstico como script standalone
void main() async {
  final diagnostic = BiometricDiagnostic();
  await diagnostic.runFullDiagnostic();
}
