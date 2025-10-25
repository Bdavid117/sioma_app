

/// Modelo para eventos personalizados del usuario (entrada/salida, etc.)
class CustomEvent {
  final int? id;
  final String eventType; // 'entrada', 'salida', 'visita', etc.
  final String eventName; // Nombre descriptivo del evento
  final String location; // 'finca', 'oficina', 'almacén', etc.
  final int personId;
  final String personName;
  final String personDocument;
  final DateTime timestamp;
  final String? notes; // Notas adicionales del usuario
  final String? photoPath; // Foto del momento del evento
  final Map<String, dynamic> metadata; // Datos adicionales
  final double? confidence; // Nivel de confianza en identificación (0.0-1.0)

  CustomEvent({
    this.id,
    required this.eventType,
    String? eventName,
    required this.location,
    required this.personId,
    required this.personName,
    required this.personDocument,
    required this.timestamp,
    this.notes,
    this.photoPath,
    this.metadata = const {},
    this.confidence,
  }) : eventName = eventName ?? _getDefaultEventName(eventType);
  
  /// Obtiene el nombre por defecto según el tipo de evento
  static String _getDefaultEventName(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      case 'visita':
        return 'Visita';
      default:
        return eventType;
    }
  }

  // Getter de compatibilidad con código antiguo
  String get documentId => personDocument;

  /// Convierte el modelo a mapa para almacenar en BD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_type': eventType,
      'event_name': eventName,
      'location': location,
      'person_id': personId,
      'person_name': personName,
      'person_document': personDocument,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'photo_path': photoPath,
      'metadata': _encodeMetadata(metadata),
      'confidence': confidence,
    };
  }

  /// Crea modelo desde mapa de BD
  factory CustomEvent.fromMap(Map<String, dynamic> map) {
    return CustomEvent(
      id: map['id']?.toInt(),
      eventType: map['event_type'] ?? '',
      eventName: map['event_name'],
      location: map['location'] ?? '',
      personId: map['person_id']?.toInt() ?? 0,
      personName: map['person_name'] ?? '',
      personDocument: map['person_document'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      notes: map['notes'],
      photoPath: map['photo_path'],
      metadata: _decodeMetadata(map['metadata']),
      confidence: map['confidence']?.toDouble(),
    );
  }

  /// Eventos predefinidos comunes
  static const Map<String, Map<String, dynamic>> predefinedEvents = {
    'entrada': {
      'name': 'Entrada',
      'icon': 'login',
      'color': 0xFF4CAF50, // Verde
      'description': 'Registro de entrada al lugar',
    },
    'salida': {
      'name': 'Salida',
      'icon': 'logout',
      'color': 0xFFF44336, // Rojo
      'description': 'Registro de salida del lugar',
    },
    'visita': {
      'name': 'Visita',
      'icon': 'person_pin_circle',
      'color': 0xFF2196F3, // Azul
      'description': 'Registro de visita temporal',
    },
    'almuerzo': {
      'name': 'Almuerzo',
      'icon': 'restaurant',
      'color': 0xFFFF9800, // Naranja
      'description': 'Salida a almuerzo',
    },
    'regreso_almuerzo': {
      'name': 'Regreso Almuerzo',
      'icon': 'restaurant_menu',
      'color': 0xFF795548, // Marrón
      'description': 'Regreso de almuerzo',
    },
    'reunion': {
      'name': 'Reunión',
      'icon': 'groups',
      'color': 0xFF9C27B0, // Púrpura
      'description': 'Asistencia a reunión',
    },
    'capacitacion': {
      'name': 'Capacitación',
      'icon': 'school',
      'color': 0xFF607D8B, // Gris azul
      'description': 'Asistencia a capacitación',
    },
    'emergencia': {
      'name': 'Emergencia',
      'icon': 'warning',
      'color': 0xFFE91E63, // Rosa fuerte
      'description': 'Evento de emergencia',
    },
  };

  /// Ubicaciones predefinidas comunes
  static const Map<String, Map<String, dynamic>> predefinedLocations = {
    'finca_principal': {
      'name': 'Finca Principal',
      'icon': 'agriculture',
      'description': 'Área principal de cultivo',
    },
    'oficina_admin': {
      'name': 'Oficina Administrativa',
      'icon': 'business',
      'description': 'Área administrativa y de oficinas',
    },
    'almacen': {
      'name': 'Almacén',
      'icon': 'warehouse',
      'description': 'Área de almacenamiento',
    },
    'laboratorio': {
      'name': 'Laboratorio',
      'icon': 'science',
      'description': 'Laboratorio de análisis',
    },
    'campo_norte': {
      'name': 'Campo Norte',
      'icon': 'grass',
      'description': 'Sector norte de cultivos',
    },
    'campo_sur': {
      'name': 'Campo Sur',
      'icon': 'grass',
      'description': 'Sector sur de cultivos',
    },
    'invernadero_1': {
      'name': 'Invernadero 1',
      'icon': 'park',
      'description': 'Invernadero principal',
    },
    'invernadero_2': {
      'name': 'Invernadero 2',
      'icon': 'park',
      'description': 'Invernadero secundario',
    },
    'entrada_principal': {
      'name': 'Entrada Principal',
      'icon': 'door_front',
      'description': 'Puerta principal de acceso',
    },
    'porteria': {
      'name': 'Portería',
      'icon': 'security',
      'description': 'Área de control de acceso',
    },
  };

  /// Factory para crear evento de entrada
  factory CustomEvent.entrada({
    required int personId,
    required String personName,
    required String personDocument,
    required String location,
    String? notes,
    String? photoPath,
  }) {
    return CustomEvent(
      eventType: 'entrada',
      location: location,
      personId: personId,
      personName: personName,
      personDocument: personDocument,
      timestamp: DateTime.now(),
      notes: notes,
      photoPath: photoPath,
      metadata: {
        'auto_generated': true,
        'device_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Factory para crear evento de salida
  factory CustomEvent.salida({
    required int personId,
    required String personName,
    required String personDocument,
    required String location,
    String? notes,
    String? photoPath,
  }) {
    return CustomEvent(
      eventType: 'salida',
      location: location,
      personId: personId,
      personName: personName,
      personDocument: personDocument,
      timestamp: DateTime.now(),
      notes: notes,
      photoPath: photoPath,
      metadata: {
        'auto_generated': true,
        'device_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Método estático para crear evento de entrada (compatible con pruebas)
  static CustomEvent createEntryEvent({
    required int personId,
    required String personName,
    required String personDocument,
    required String location,
    String? notes,
  }) {
    return CustomEvent.entrada(
      personId: personId,
      personName: personName,
      personDocument: personDocument,
      location: location,
      notes: notes,
    );
  }

  /// Método estático para crear evento de salida (compatible con pruebas)
  static CustomEvent createExitEvent({
    required int personId,
    required String personName,
    required String personDocument,
    required String location,
    String? notes,
  }) {
    return CustomEvent.salida(
      personId: personId,
      personName: personName,
      personDocument: personDocument,
      location: location,
      notes: notes,
    );
  }

  /// Obtiene información del tipo de evento
  Map<String, dynamic> getEventTypeInfo() {
    return predefinedEvents[eventType] ?? {
      'name': eventType,
      'icon': 'event',
      'color': 0xFF757575,
      'description': 'Evento personalizado',
    };
  }

  /// Obtiene información de la ubicación
  Map<String, dynamic> getLocationInfo() {
    return predefinedLocations[location] ?? {
      'name': location,
      'icon': 'location_on',
      'description': 'Ubicación personalizada',
    };
  }

  /// Verifica si es un evento de entrada
  bool get isEntrada => eventType == 'entrada';

  /// Verifica si es un evento de salida
  bool get isSalida => eventType == 'salida';

  /// Obtiene descripción legible del evento
  String get description {
    final eventInfo = getEventTypeInfo();
    final locationInfo = getLocationInfo();
    return '${eventInfo['name']} en ${locationInfo['name']}';
  }

  /// Codifica metadata como JSON string
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    try {
      return metadata.isEmpty ? '{}' : 
             metadata.map((k, v) => MapEntry(k, v.toString())).toString();
    } catch (e) {
      return '{}';
    }
  }

  /// Decodifica metadata desde JSON string
  static Map<String, dynamic> _decodeMetadata(String? encoded) {
    if (encoded == null || encoded.isEmpty || encoded == '{}') {
      return <String, dynamic>{};
    }
    
    try {
      // Implementación simple - en producción usar json.decode
      return <String, dynamic>{
        'raw': encoded,
      };
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Crea copia con campos modificados
  CustomEvent copyWith({
    int? id,
    String? eventType,
    String? location,
    int? personId,
    String? personName,
    String? personDocument,
    DateTime? timestamp,
    String? notes,
    String? photoPath,
    Map<String, dynamic>? metadata,
  }) {
    return CustomEvent(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      location: location ?? this.location,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      personDocument: personDocument ?? this.personDocument,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'CustomEvent(id: $id, eventType: $eventType, location: $location, personName: $personName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomEvent &&
      other.id == id &&
      other.eventType == eventType &&
      other.location == location &&
      other.personId == personId &&
      other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      eventType.hashCode ^
      location.hashCode ^
      personId.hashCode ^
      timestamp.hashCode;
  }
}