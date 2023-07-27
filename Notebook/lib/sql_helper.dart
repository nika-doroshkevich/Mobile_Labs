import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sql;

class SQLHelper {
  static Future<void> createTables(sql.Database database) async {
    await database.execute("""CREATE TABLE items(
    id INTEGER PRIMARY KEY NOT NULL,
    title TEXT,
    description TEXT,
    createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
    """);

    await database.execute("""CREATE TABLE synchronize(
    id INTEGER,
    hashSum TEXT
    )
    """);

    await database.execute("""INSERT INTO synchronize VALUES(
    1,
    ''
    )
    """);

  }

  static Future<sql.Database> db() async {
    return sql.openDatabase(
      'db-lab-1-2.db',
      version: 1,
      onCreate: (sql.Database database, int version) async {
        await createTables(database);
      },
    );
  }

  static Future<int> createItem(int id, String title, String? description) async {
    final db = await SQLHelper.db();

    final data = {'id': id, 'title': title, 'description': description};
    final item = await db.insert('items', data,
    conflictAlgorithm: sql.ConflictAlgorithm.replace);
    return item;
  }

  static Future<List<Map<String, dynamic>>> getItems() async {
    final db = await SQLHelper.db();
    return db.query('items', orderBy: "id");
  }

  static Future<int> updateItem(
      int id, String title, String? description) async {
    final db = await SQLHelper.db();

    final data = {
      'title': title,
      'description': description
    };

    final result =
        await db.update('items', data, where: "id = ?", whereArgs: [id]);
    return result;
  }

  static Future<void> deleteItem(int id) async {
    final db = await SQLHelper.db();
    try {
      await db.delete('items', where: "id = ?", whereArgs: [id]);
    } catch (err) {
      debugPrint("Something went wrong when deleting an item: $err");
    }
  }

  static Future<List<Map<String, dynamic>>> getHashSum(int id) async {
    final db = await SQLHelper.db();
    return db.query('synchronize', where: "id = ?", whereArgs: [id], limit: 1);
  }

  static Future<int> updateHashSum(int id, String newHashSum) async {
    final db = await SQLHelper.db();

    final data = {
      'id': id,
      'hashSum': newHashSum
    };

    final result =
    await db.update('synchronize', data, where: "id = ?", whereArgs: [id]);
    return result;
  }
}