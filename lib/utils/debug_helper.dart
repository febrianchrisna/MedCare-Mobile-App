import 'package:flutter/material.dart';
import 'package:medcareapp/services/database_helper.dart';
import 'package:medcareapp/utils/shared_prefs_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DebugHelper extends StatelessWidget {
  const DebugHelper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Info')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getDebugInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SharedPreferences Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                _buildJsonViewer(data['sharedPrefs']),

                const SizedBox(height: 24),

                Text(
                  'Database Tables',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                _buildJsonViewer(data['database']),

                ElevatedButton(
                  onPressed: () async {
                    try {
                      final helper = DatabaseHelper();

                      // Force a complete database reset using a different approach
                      final db = await helper.database;
                      await db.close();

                      final path = join(await getDatabasesPath(), 'medcare.db');
                      if (await databaseExists(path)) {
                        await deleteDatabase(path);
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Database reset successfully!'),
                        ),
                      );

                      // Reload page after reset
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebugHelper(),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error resetting database: $e')),
                      );
                    }
                  },
                  child: const Text('Reset Database'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    await SharedPrefsHelper.clearAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SharedPrefs cleared!')),
                    );
                  },
                  child: const Text('Clear SharedPreferences'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildJsonViewer(dynamic data) {
    if (data is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            data.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _buildJsonViewer(entry.value),
                    ),
                  ],
                ),
              );
            }).toList(),
      );
    } else if (data is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < data.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$i: '),
                  Expanded(child: _buildJsonViewer(data[i])),
                ],
              ),
            ),
        ],
      );
    } else {
      return Text(data?.toString() ?? 'null');
    }
  }

  Future<Map<String, dynamic>> _getDebugInfo() async {
    // Get all SharedPreferences data
    final sharedPrefs = await SharedPrefsHelper.getAllStoredData();

    // Get database tables info
    final db = await DatabaseHelper().database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );

    Map<String, dynamic> dbData = {};

    for (var table in tables) {
      final tableName = table['name'] as String;
      if (!tableName.startsWith('sqlite_')) {
        final rows = await db.query(tableName);
        dbData[tableName] = rows;
      }
    }

    return {'sharedPrefs': sharedPrefs, 'database': dbData};
  }
}
