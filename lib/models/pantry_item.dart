// models/pantry_item.dart

enum PantryLocation {
  cupboard,
  fridge,
  freezer,
}

extension PantryLocationX on PantryLocation {
  String get dbValue {
    switch (this) {
      case PantryLocation.cupboard:
        return 'cupboard';
      case PantryLocation.fridge:
        return 'fridge';
      case PantryLocation.freezer:
        return 'freezer';
    }
  }

  String get displayName {
    switch (this) {
      case PantryLocation.cupboard:
        return 'Cupboard';
      case PantryLocation.fridge:
        return 'Fridge';
      case PantryLocation.freezer:
        return 'Freezer';
    }
  }

  static PantryLocation fromDbValue(String? raw) {
    switch (raw) {
      case 'fridge':
        return PantryLocation.fridge;
      case 'freezer':
        return PantryLocation.freezer;
      case 'cupboard':
      default:
        return PantryLocation.cupboard;
    }
  }
}

class PantryItem {
  final int id;
  final String name;
  final String normalizedName;
  final PantryLocation location;
  final DateTime createdAt;
  final DateTime updatedAt;

  PantryItem({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  PantryItem copyWith({
    int? id,
    String? name,
    String? normalizedName,
    PantryLocation? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String normalize(String input) {
    return input.trim().toLowerCase();
  }

  factory PantryItem.fromDb(Map<String, Object?> m) {
    return PantryItem(
      id: (m['id'] as num).toInt(),
      name: (m['name'] as String?) ?? '',
      normalizedName: (m['normalized_name'] as String?) ?? '',
      location: PantryLocationX.fromDbValue(m['location'] as String?),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Map<String, Object?> toDbMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'name': name,
      'normalized_name': normalizedName,
      'location': location.dbValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
