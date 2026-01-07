// state/pantry_model.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:chef/models/pantry_item.dart';
import 'package:chef/repository/pantry_repository.dart';

class PantryModel extends ChangeNotifier {
  final PantryRepository repo;

  List<PantryItem> _items = [];
  List<PantryItem> get items => _items;

  StreamSubscription<List<PantryItem>>? _sub;
  bool _loading = false;
  bool get loading => _loading;

  PantryModel({required this.repo});

  Future<void> init() async {
    _sub = repo.stream.listen((list) {
      _items = list;
      notifyListeners();
    });

    await repo.loadLocal();
  }

  List<PantryItem> itemsFor(PantryLocation location) {
    return _items.where((i) => i.location == location).toList(growable: false);
  }

  Future<void> addMany({
    required PantryLocation location,
    required List<String> names,
  }) async {
    await repo.addMany(location: location, names: names);
  }

  Future<void> rename({
    required int id,
    required String newName,
  }) async {
    await repo.rename(id: id, newName: newName);
  }

  Future<void> move({
    required int id,
    required PantryLocation newLocation,
  }) async {
    await repo.move(id: id, newLocation: newLocation);
  }

  Future<void> delete(int id) async {
    await repo.delete(id);
  }

  Future<void> clearLocation(PantryLocation location) async {
    await repo.clearLocation(location);
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      await repo.loadLocal();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
