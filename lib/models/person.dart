/// Modelo para representar una persona registrada
class Person {
  final int? id;
  final String name;
  final String documentId;
  final String? photoPath;
  final String embedding; // JSON string de la lista de embeddings
  final DateTime createdAt;

  Person({
    this.id,
    required this.name,
    required this.documentId,
    this.photoPath,
    required this.embedding,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convierte el objeto a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'document_id': documentId,
      'photo_path': photoPath,
      'embedding': embedding,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea un objeto Person desde un Map de SQLite
  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      documentId: map['document_id'] as String,
      photoPath: map['photo_path'] as String?,
      embedding: map['embedding'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Copia el objeto con valores actualizados
  Person copyWith({
    int? id,
    String? name,
    String? documentId,
    String? photoPath,
    String? embedding,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      documentId: documentId ?? this.documentId,
      photoPath: photoPath ?? this.photoPath,
      embedding: embedding ?? this.embedding,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
