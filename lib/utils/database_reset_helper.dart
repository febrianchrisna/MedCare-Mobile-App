import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

class DatabaseResetHelper {
  // Forcefully reset the database
  static Future<void> forceResetDatabase() async {
    try {
      print('===== EMERGENCY DATABASE RESET INITIATED =====');

      // Get database path
      final dbPath = join(await getDatabasesPath(), 'medcare.db');
      print('Database path: $dbPath');

      // Force close any connections that might be open
      try {
        final db = await openDatabase(dbPath, readOnly: true);
        await db.close();
        print('Closed any existing database connections');
      } catch (e) {
        print('No database connections to close: $e');
      }

      // Wait to ensure connections are fully closed
      await Future.delayed(const Duration(milliseconds: 500));

      // Delete the database file directly first
      try {
        final file = File(dbPath);
        if (await file.exists()) {
          await file.delete();
          print('Deleted database file directly');
        }
      } catch (e) {
        print('Error deleting file directly: $e');
      }

      // Try SQFLite's method as a fallback
      if (await databaseExists(dbPath)) {
        await deleteDatabase(dbPath);
        print('Deleted database using SQFLite');
      }

      // Also clean up journal files
      try {
        final dir = Directory(dirname(dbPath));
        final files = await dir.list().toList();
        for (var file in files) {
          if (file is File &&
              (file.path.contains('-journal') ||
                  file.path.contains('-wal') ||
                  file.path.contains('-shm'))) {
            await file.delete();
            print('Deleted related file: ${file.path}');
          }
        }
      } catch (e) {
        print('Error cleaning up associated files: $e');
      }

      print('===== DATABASE RESET COMPLETE =====');
    } catch (e) {
      print('===== ERROR DURING DATABASE RESET: $e =====');
      rethrow;
    }
  }
}
