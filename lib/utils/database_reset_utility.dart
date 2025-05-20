import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseResetUtility {
  static const String DATABASE_NAME = 'medcare.db';

  /// Emergency database reset - completely removes and recreates the database file
  static Future<bool> emergencyReset() async {
    try {
      print('===== EMERGENCY DATABASE RESET INITIATED =====');

      // Get database path
      final dbPath = join(await getDatabasesPath(), DATABASE_NAME);
      print('Database path: $dbPath');

      // Force close any open connections
      await closeDatabase();

      // Delete the database file
      if (await databaseExists(dbPath)) {
        try {
          // Try direct file deletion first
          final dbFile = File(dbPath);
          await dbFile.delete();
          print('Database file deleted: $dbPath');
        } catch (e) {
          print('Error deleting database file directly: $e');

          // Try SQFLite's deleteDatabase as fallback
          await deleteDatabase(dbPath);
          print('Database deleted using SQFLite');
        }
      } else {
        print('No database file found at: $dbPath');
      }

      // Also delete any journal or temporary files
      try {
        await _cleanupRelatedFiles(dbPath);
      } catch (e) {
        print('Error cleaning up related files: $e');
      }

      print('===== EMERGENCY DATABASE RESET COMPLETED =====');
      return true;
    } catch (e) {
      print('===== EMERGENCY DATABASE RESET FAILED: $e =====');
      return false;
    }
  }

  /// Try to force close all database connections
  static Future<void> closeDatabase() async {
    try {
      // The correct way to close a database is to open it first then close it
      final dbPath = join(await getDatabasesPath(), DATABASE_NAME);

      if (await databaseExists(dbPath)) {
        // Open the database first
        final db = await openDatabase(dbPath, readOnly: true);
        // Then close it properly
        await db.close();
        print('Database connection closed properly');
      } else {
        print('No database exists at path to close');
      }

      // Add a delay to ensure IO operations complete
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error closing database: $e');
    }
  }

  /// Clean up any related database files
  static Future<void> _cleanupRelatedFiles(String dbPath) async {
    try {
      final directory = Directory(dirname(dbPath));
      if (await directory.exists()) {
        final files = directory.listSync();
        for (var file in files) {
          if (file is File &&
              (file.path.contains('${basename(dbPath)}-journal') ||
                  file.path.contains('${basename(dbPath)}-wal') ||
                  file.path.contains('${basename(dbPath)}-shm'))) {
            await file.delete();
            print('Deleted related file: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up related files: $e');
    }
  }

  /// Clear application cache and data files
  static Future<void> clearAppCache() async {
    try {
      // Get app cache directory
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
        print('App cache cleared');
      }
    } catch (e) {
      print('Error clearing app cache: $e');
    }
  }
}
