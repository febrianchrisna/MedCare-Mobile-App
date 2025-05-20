import 'package:flutter/material.dart';
import 'package:medcareapp/services/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DebugButton extends StatelessWidget {
  const DebugButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.red,
      child: const Icon(Icons.bug_report),
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Debug Tools'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (ctx) => const AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Resetting database...'),
                                  ],
                                ),
                              ),
                        );

                        try {
                          // Reset database
                          await DatabaseHelper().resetDatabase();

                          // Close loading dialog
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Database reset successful!'),
                            ),
                          );
                        } catch (e) {
                          // Close loading dialog
                          Navigator.pop(context);

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Reset Database'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Show database info
                          final dbPath = join(
                            await getDatabasesPath(),
                            'medcare.db',
                          );
                          final db = await openDatabase(dbPath, readOnly: true);
                          final tables = await db.rawQuery(
                            "SELECT name FROM sqlite_master WHERE type='table'",
                          );
                          await db.close();

                          // Close dialog first
                          Navigator.pop(context);

                          // Show database info
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text('Database Info'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Database Tables:'),
                                        const SizedBox(height: 8),
                                        ...tables.map(
                                          (t) => Text('- ${t['name']}'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Show Database Info'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      },
    );
  }
}
