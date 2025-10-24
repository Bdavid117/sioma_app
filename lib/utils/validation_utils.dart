import 'dart:convert';

/// Utilidades de validación y sanitización de datos
class ValidationUtils {
  static const int maxNameLength = 100;
  static const int maxDocumentLength = 20;
  static const int minNameLength = 2;
  static const int minDocumentLength = 5;

  /// Valida el nombre de una persona
  static ValidationResult validatePersonName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return ValidationResult.error('El nombre es requerido');
    }

    final trimmedName = name.trim();

    if (trimmedName.length < minNameLength) {
      return ValidationResult.error('El nombre debe tener al menos $minNameLength caracteres');
    }

    if (trimmedName.length > maxNameLength) {
      return ValidationResult.error('El nombre no puede exceder $maxNameLength caracteres');
    }

    // Solo permitir letras, espacios, apostrofes y guiones
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s\x27-]+$');
    if (!nameRegex.hasMatch(trimmedName)) {
      return ValidationResult.error('El nombre solo puede contener letras, espacios y caracteres válidos');
    }

    return ValidationResult.success(trimmedName);
  }

  /// Valida el número de documento
  static ValidationResult validateDocumentId(String? documentId) {
    if (documentId == null || documentId.trim().isEmpty) {
      return ValidationResult.error('El documento es requerido');
    }

    final trimmedDocument = documentId.trim().replaceAll(RegExp(r'\s+'), '');

    if (trimmedDocument.length < minDocumentLength) {
      return ValidationResult.error('El documento debe tener al menos $minDocumentLength caracteres');
    }

    if (trimmedDocument.length > maxDocumentLength) {
      return ValidationResult.error('El documento no puede exceder $maxDocumentLength caracteres');
    }

    // Solo permitir números, letras y algunos caracteres especiales
    final documentRegex = RegExp(r'^[a-zA-Z0-9-_]+$');
    if (!documentRegex.hasMatch(trimmedDocument)) {
      return ValidationResult.error('El documento solo puede contener letras, números y guiones');
    }

    return ValidationResult.success(trimmedDocument.toUpperCase());
  }

  /// Valida una ruta de archivo
  static ValidationResult validateFilePath(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) {
      return ValidationResult.error('La ruta del archivo es requerida');
    }

    final trimmedPath = filePath.trim();

    // Verificar que no contenga caracteres peligrosos
    final dangerousChars = ['../', '..\\', '<', '>', '|', '*', '?'];
    for (final char in dangerousChars) {
      if (trimmedPath.contains(char)) {
        return ValidationResult.error('La ruta contiene caracteres no permitidos');
      }
    }

    // Verificar extensión de imagen
    final allowedExtensions = ['.jpg', '.jpeg', '.png'];
    final hasValidExtension = allowedExtensions.any(
      (ext) => trimmedPath.toLowerCase().endsWith(ext)
    );

    if (!hasValidExtension) {
      return ValidationResult.error('Formato de imagen no válido. Use: ${allowedExtensions.join(', ')}');
    }

    return ValidationResult.success(trimmedPath);
  }

  /// Valida datos de embedding JSON
  static ValidationResult validateEmbeddingJson(String? embeddingJson) {
    if (embeddingJson == null || embeddingJson.trim().isEmpty) {
      return ValidationResult.error('Los datos de embedding son requeridos');
    }

    try {
      final decoded = jsonDecode(embeddingJson);

      if (decoded is! List) {
        return ValidationResult.error('El embedding debe ser una lista de números');
      }

      final embeddings = decoded.cast<double>();

      if (embeddings.isEmpty) {
        return ValidationResult.error('El embedding no puede estar vacío');
      }

      if (embeddings.length < 64 || embeddings.length > 1024) {
        return ValidationResult.error('El embedding debe tener entre 64 y 1024 dimensiones');
      }

      // Verificar que todos los valores sean números válidos
      for (final value in embeddings) {
        if (value.isNaN || value.isInfinite) {
          return ValidationResult.error('El embedding contiene valores inválidos');
        }
      }

      return ValidationResult.success(embeddingJson);
    } catch (e) {
      return ValidationResult.error('Formato de embedding inválido: ${e.toString()}');
    }
  }

  /// Sanitiza texto para prevenir problemas de codificación
  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')  // Normalizar espacios
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s\x27-]', unicode: true), ''); // Remover caracteres peligrosos
  }

  /// Genera un ID único seguro
  static String generateSecureId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = (timestamp * 1000 + now.microsecond) % 999999;
    return '${timestamp.toRadixString(36)}_${random.toRadixString(36)}';
  }
}

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? value;

  const ValidationResult._(this.isValid, this.error, this.value);

  factory ValidationResult.success(String value) => ValidationResult._(true, null, value);
  factory ValidationResult.error(String error) => ValidationResult._(false, error, null);

  /// Lanza excepción si la validación falló
  String getValueOrThrow() {
    if (!isValid) {
      throw ArgumentError(error ?? 'Validación fallida');
    }
    return value!;
  }
}

/// Excepciones personalizadas para la aplicación
class SiomaValidationException implements Exception {
  final String message;
  final String field;

  const SiomaValidationException(this.message, this.field);

  @override
  String toString() => 'Validation Error [$field]: $message';
}

class SiomaDatabaseException implements Exception {
  final String message;
  final String? originalError;

  const SiomaDatabaseException(this.message, [this.originalError]);

  @override
  String toString() => 'Database Error: $message${originalError != null ? ' (Original: $originalError)' : ''}';
}
