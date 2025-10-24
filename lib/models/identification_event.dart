/// Modelo para representar un evento de identificación
class IdentificationEvent {
  final int? id;
  final int? personId; // null si no se identificó a nadie
  final String? personName;
  final double? confidence; // Nivel de confianza de la identificación
  final String? photoPath;
  final DateTime timestamp;
  final bool identified; // true si se identificó, false si fue desconocido

  IdentificationEvent({
    this.id,
    this.personId,
    this.personName,
    this.confidence,
    this.photoPath,
    DateTime? timestamp,
    required this.identified,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convierte el objeto a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'person_name': personName,
      'confidence': confidence,
      'photo_path': photoPath,
      'timestamp': timestamp.toIso8601String(),
      'identified': identified ? 1 : 0,
    };
  }

  /// Crea un objeto IdentificationEvent desde un Map de SQLite
  factory IdentificationEvent.fromMap(Map<String, dynamic> map) {
    return IdentificationEvent(
      id: map['id'] as int?,
      personId: map['person_id'] as int?,
      personName: map['person_name'] as String?,
      confidence: map['confidence'] as double?,
      photoPath: map['photo_path'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      identified: (map['identified'] as int) == 1,
    );
  }
}
