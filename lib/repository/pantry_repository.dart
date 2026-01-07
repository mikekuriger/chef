// repository/pantry_repository.dart
import 'dart:async';

import 'package:chef/data/pantry_dao.dart';
import 'package:chef/models/pantry_item.dart';

class PantryRepository {
  final _dao = PantryDao();
  final _controller = StreamController<List<PantryItem>>.broadcast();
  Stream<List<PantryItem>> get stream => _controller.stream;

  Future<List<PantryItem>> loadLocal({PantryLocation? location}) async {
    final local = await _dao.getAll(location: location);
    _controller.add(local);
    return local;
  }

  Future<void> addMany({
    required PantryLocation location,
    required List<String> names,
  }) async {
    await _dao.upsertMany(location: location, names: names);
    await loadLocal();
  }

  Future<void> rename({
    required int id,
    required String newName,
  }) async {
    await _dao.rename(id: id, newName: newName);
    await loadLocal();
  }

  Future<void> move({
    required int id,
    required PantryLocation newLocation,
  }) async {
    await _dao.move(id: id, newLocation: newLocation);
    await loadLocal();
  }

  Future<void> delete(int id) async {
    await _dao.delete(id);
    await loadLocal();
  }

  Future<void> clearLocation(PantryLocation location) async {
    await _dao.clearLocation(location);
    await loadLocal();
  }

  void dispose() => _controller.close();
}
