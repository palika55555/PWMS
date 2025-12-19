import '../database/database_helper.dart';
import '../models/material.dart';

class MaterialService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Získanie všetkých materiálov
  Future<List<Material>> getAllMaterials() async {
    final db = await _db.database;
    final maps = await db.query(
      'materials',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => Material.fromMap(maps[i]));
  }

  // Získanie materiálu podľa ID
  Future<Material?> getMaterialById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Material.fromMap(maps.first);
  }

  // Získanie materiálu podľa názvu
  Future<Material?> getMaterialByName(String name) async {
    final db = await _db.database;
    final maps = await db.query(
      'materials',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (maps.isEmpty) return null;
    return Material.fromMap(maps.first);
  }

  // Aktualizácia množstva materiálu
  Future<int> updateMaterialQuantity(int id, double newQuantity) async {
    final db = await _db.database;
    return await db.update(
      'materials',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Pridanie množstva k materiálu
  Future<int> addMaterialQuantity(int id, double quantityToAdd) async {
    final material = await getMaterialById(id);
    if (material == null) return 0;

    final newQuantity = material.quantity + quantityToAdd;
    return await updateMaterialQuantity(id, newQuantity);
  }

  // Odčítanie množstva z materiálu
  Future<int> subtractMaterialQuantity(int id, double quantityToSubtract) async {
    final material = await getMaterialById(id);
    if (material == null) return 0;

    final newQuantity = (material.quantity - quantityToSubtract).clamp(0.0, double.infinity);
    return await updateMaterialQuantity(id, newQuantity);
  }
}

