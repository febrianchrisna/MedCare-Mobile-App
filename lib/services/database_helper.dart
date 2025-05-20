import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/models/cart_item.dart';
import 'package:medcareapp/models/order.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Table names
  static const String tableMedicines = 'medicines';
  static const String tableCartItems = 'cart_items';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'medcare.db');

    try {
      print('Initializing database at $path (version 7)');
      return await openDatabase(
        path,
        version: 7, // Increment to force upgrade
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
        onConfigure: _onConfigure,
        singleInstance: true,
      );
    } catch (e) {
      print('ERROR opening database: $e');
      rethrow;
    }
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from v$oldVersion to v$newVersion');

    try {
      // For ALL upgrades, completely drop and recreate tables to fix issues
      print('Dropping all tables for clean upgrade');

      // Drop in reverse order to respect foreign keys
      await db.execute('DROP TABLE IF EXISTS $tableOrderItems');
      await db.execute('DROP TABLE IF EXISTS $tableOrders');
      await db.execute('DROP TABLE IF EXISTS $tableCartItems');
      await db.execute('DROP TABLE IF EXISTS $tableMedicines');

      print('All tables dropped, recreating them now');

      // Recreate all tables
      await _createDb(db, newVersion);

      print('Database upgrade completed successfully');
    } catch (e) {
      print('ERROR during database upgrade: $e');
      // Let the error propagate
      throw e;
    }
  }

  // Enhanced _createDb with better error handling
  Future<void> _createDb(Database db, int version) async {
    try {
      // Create each table separately with explicit error handling

      // 1. First create medicines table
      print('Creating medicines table');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMedicines(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        image TEXT,
        category TEXT NOT NULL,
        stock INTEGER DEFAULT 0,
        manufacturer TEXT,
        dosage TEXT,
        expiry_date TEXT,
        featured INTEGER DEFAULT 0
      )
      ''');
      // 2. Create cart items table
      print('Creating cart items table');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCartItems(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineId INTEGER NOT NULL,
        medicineName TEXT NOT NULL,
        medicineImage TEXT,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1
      )
      ''');

      // 3. Create orders table
      print('Creating orders table');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrders(
        id INTEGER PRIMARY KEY,
        userId TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL,
        address TEXT,
        paymentMethod TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
      ''');

      // 4. Create order items table
      print('Creating order items table');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrderItems(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        medicineId INTEGER NOT NULL,
        medicineName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        medicineImage TEXT,
        FOREIGN KEY (orderId) REFERENCES $tableOrders(id) ON DELETE CASCADE
      )
      ''');

      print('All tables created successfully');
    } catch (e) {
      print('ERROR in _createDb: $e');
      throw e;
    }
  }

  // Configure database to enable foreign keys
  Future<void> _onConfigure(Database db) async {
    try {
      // Enable foreign key constraints
      await db.execute('PRAGMA foreign_keys = ON');
      print('Foreign keys enabled for database');
    } catch (e) {
      print('Error configuring database: $e');
      // Continue anyway, as this is not critical
    }
  }

  // Validate that all needed tables exist
  Future<void> _validateTables(Database db) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toList();

      print('Existing tables: $tableNames');

      // Check if our required tables exist
      final requiredTables = [
        tableMedicines,
        tableCartItems,
        tableOrders,
        tableOrderItems,
      ];

      for (final table in requiredTables) {
        if (!tableNames.contains(table)) {
          print('Table $table is missing - recreating');
          if (table == tableMedicines) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableMedicines(
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              price REAL NOT NULL,
              image TEXT,
              category TEXT NOT NULL,
              stock INTEGER DEFAULT 0,
              manufacturer TEXT,
              dosage TEXT,
              expiry_date TEXT,
              featured INTEGER DEFAULT 0
            )
            ''');
          } else if (table == tableCartItems) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableCartItems(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medicineId INTEGER NOT NULL,
              medicineName TEXT NOT NULL,
              medicineImage TEXT,
              price REAL NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1
            )
            ''');
          } else if (table == tableOrders) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableOrders(
              id INTEGER PRIMARY KEY,
              userId TEXT NOT NULL, 
              totalAmount REAL NOT NULL,
              status TEXT NOT NULL,
              address TEXT,
              paymentMethod TEXT,
              notes TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT
            )
            ''');
          } else if (table == tableOrderItems) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS $tableOrderItems(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              orderId INTEGER NOT NULL,
              medicineId INTEGER NOT NULL,
              medicineName TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              price REAL NOT NULL,
              medicineImage TEXT,
              FOREIGN KEY (orderId) REFERENCES $tableOrders(id) ON DELETE CASCADE
            )
            ''');
          }
        }
      }
    } catch (e) {
      print('Error validating tables: $e');
    }
  }

  // Order Methods

  // Create new order with its items
  Future<int> insertOrder(Order order) async {
    final db = await database;

    // Enhanced debugging
    print('DEBUG: Inserting order for user: ${order.userId}');

    // Ensure order ID is valid
    int orderIdToUse = order.id ?? -DateTime.now().millisecondsSinceEpoch;

    try {
      // Use transaction to ensure data consistency
      return await db.transaction((txn) async {
        try {
          // Insert the order with explicit column names to avoid errors
          final orderId = await txn.insert(tableOrders, {
            'id': orderIdToUse,
            'userId': order.userId,
            'totalAmount': order.totalAmount,
            'status': order.status,
            'address': order.address ?? '',
            'paymentMethod': order.paymentMethod ?? '',
            'notes': order.notes ?? '',
            'createdAt': order.createdAt.toIso8601String(),
            'updatedAt': order.updatedAt?.toIso8601String() ?? '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          print('Order inserted with ID: $orderId');

          // Insert all order items
          for (var item in order.items) {
            await txn.insert(tableOrderItems, {
              'orderId': orderId,
              'medicineId': item.medicineId,
              'medicineName': item.medicineName,
              'quantity': item.quantity,
              'price': item.price,
              'medicineImage': item.medicineImage ?? '',
            });
          }

          print('All order items inserted successfully');
          return orderId;
        } catch (e) {
          print('Transaction error: $e');
          throw e; // Rethrow to roll back transaction
        }
      }, exclusive: true);
    } catch (e) {
      print('Error inserting order: $e');
      throw e; // Rethrow to handle in UI
    }
  }

  // Get a specific order by ID with enhanced medicine name lookup
  Future<Order?> getOrderById(int id) async {
    final db = await database;

    try {
      // Fetch order details
      final List<Map<String, dynamic>> orderMaps = await db.query(
        tableOrders,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (orderMaps.isEmpty) return null;

      final orderMap = orderMaps.first;

      // Fetch order items
      final List<Map<String, dynamic>> itemMaps = await db.query(
        tableOrderItems,
        where: 'orderId = ?',
        whereArgs: [id],
      );

      // Create order items
      final items = await Future.wait(
        itemMaps.map((itemMap) async {
          // Try to get the actual medicine name from the medicines table
          String medicineName =
              itemMap['medicineName'] as String? ?? 'Unknown Medicine';
          String? medicineImage = itemMap['medicineImage'] as String?;

          // If the medicine name is unknown or empty, try to get it from the medicines table
          if (medicineName.isEmpty || medicineName == 'Unknown Medicine') {
            try {
              final medicineId = itemMap['medicineId'] as int;
              final medicineData = await db.query(
                tableMedicines,
                where: 'id = ?',
                whereArgs: [medicineId],
              );

              if (medicineData.isNotEmpty) {
                medicineName =
                    medicineData.first['name'] as String? ?? medicineName;
                medicineImage =
                    medicineData.first['image'] as String? ?? medicineImage;
              }
            } catch (e) {
              print('Error getting medicine data: $e');
            }
          }

          return OrderItem(
            medicineId: itemMap['medicineId'] as int,
            medicineName: medicineName,
            quantity: itemMap['quantity'] as int,
            price:
                (itemMap['price'] is int)
                    ? (itemMap['price'] as int).toDouble()
                    : itemMap['price'] as double,
            medicineImage: medicineImage,
          );
        }).toList(),
      );

      // Return complete order
      return Order(
        id: orderMap['id'] as int,
        userId: orderMap['userId'] as String,
        items: items,
        totalAmount:
            (orderMap['totalAmount'] is int)
                ? (orderMap['totalAmount'] as int).toDouble()
                : orderMap['totalAmount'] as double,
        status: orderMap['status'] as String,
        address: orderMap['address'] as String?,
        paymentMethod: orderMap['paymentMethod'] as String?,
        notes: orderMap['notes'] as String?,
        createdAt: DateTime.parse(orderMap['createdAt'] as String),
        updatedAt:
            orderMap['updatedAt'] != null
                ? DateTime.parse(orderMap['updatedAt'] as String)
                : null,
      );
    } catch (e) {
      print('Error retrieving order by ID: $e');
      return null;
    }
  }

  // Update order status
  Future<int> updateOrderStatus(int orderId, String status) async {
    final db = await database;
    try {
      return await db.update(
        tableOrders,
        {'status': status, 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      print('Error updating order status: $e');
      return 0;
    }
  }

  // Update order details
  Future<int> updateOrder(Order order) async {
    final db = await database;
    try {
      return await db.update(
        tableOrders,
        {
          'totalAmount': order.totalAmount,
          'status': order.status,
          'address': order.address,
          'paymentMethod': order.paymentMethod,
          'notes': order.notes,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
    } catch (e) {
      print('Error updating order: $e');
      return 0;
    }
  }

  // Delete an order and its items (cascade)
  Future<int> deleteOrder(int orderId) async {
    final db = await database;

    try {
      // First delete related order items
      await db.delete(
        tableOrderItems,
        where: 'orderId = ?',
        whereArgs: [orderId],
      );

      // Then delete the order
      return await db.delete(
        tableOrders,
        where: 'id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      print('Error deleting order: $e');
      return 0;
    }
  }

  // Delete all orders for a user
  Future<int> deleteAllUserOrders(String userId) async {
    final db = await database;
    try {
      return await db.delete(
        tableOrders,
        where: 'userId = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error deleting all user orders: $e');
      return 0;
    }
  }

  // Get all orders for a specific user
  Future<List<Order>> getOrdersByUserId(String userId) async {
    final db = await database;

    try {
      // Query orders for this user
      final orderMaps = await db.query(
        tableOrders,
        where: 'userId = ?',
        whereArgs: [userId],
      );

      print('Found ${orderMaps.length} orders for user $userId');

      // Build complete orders with their items
      List<Order> orders = [];

      for (var orderMap in orderMaps) {
        final orderId = orderMap['id'] as int;

        // Get items for this order
        final itemMaps = await db.query(
          tableOrderItems,
          where: 'orderId = ?',
          whereArgs: [orderId],
        );

        // Create order items
        final items =
            itemMaps
                .map(
                  (itemMap) => OrderItem(
                    medicineId: itemMap['medicineId'] as int,
                    medicineName: itemMap['medicineName'] as String,
                    quantity: itemMap['quantity'] as int,
                    price:
                        (itemMap['price'] is int)
                            ? (itemMap['price'] as int).toDouble()
                            : itemMap['price'] as double,
                    medicineImage: itemMap['medicineImage'] as String?,
                  ),
                )
                .toList();

        // Create and add order
        orders.add(
          Order(
            id: orderId,
            userId: orderMap['userId'] as String,
            items: items,
            totalAmount:
                (orderMap['totalAmount'] is int)
                    ? (orderMap['totalAmount'] as int).toDouble()
                    : orderMap['totalAmount'] as double,
            status: orderMap['status'] as String,
            address: orderMap['address'] as String?,
            paymentMethod: orderMap['paymentMethod'] as String?,
            notes: orderMap['notes'] as String?,
            createdAt: DateTime.parse(orderMap['createdAt'] as String),
            updatedAt:
                orderMap['updatedAt'] != null
                    ? DateTime.parse(orderMap['updatedAt'] as String)
                    : null,
          ),
        );
      }

      return orders;
    } catch (e) {
      print('Error getting orders by user ID: $e');
      return [];
    }
  }

  // Cart Methods

  // Get all cart items
  Future<List<CartItem>> getCartItems() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(tableCartItems);
      return List.generate(maps.length, (i) => CartItem.fromMap(maps[i]));
    } catch (e) {
      print('Error getting cart items: $e');
      return [];
    }
  }

  // Get cart item by medicine ID
  Future<CartItem?> getCartItemByMedicineId(int medicineId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableCartItems,
        where: 'medicineId = ?',
        whereArgs: [medicineId],
      );

      if (maps.isEmpty) return null;
      return CartItem.fromMap(maps.first);
    } catch (e) {
      print('Error getting cart item by medicine ID: $e');
      return null;
    }
  }

  // Insert a cart item
  Future<int> insertCartItem(CartItem item) async {
    final db = await database;
    try {
      return await db.insert(
        tableCartItems,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting cart item: $e');
      return -1;
    }
  }

  // Update a cart item
  Future<int> updateCartItem(CartItem item) async {
    final db = await database;
    try {
      return await db.update(
        tableCartItems,
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } catch (e) {
      print('Error updating cart item: $e');
      return 0;
    }
  }

  // Delete a cart item
  Future<int> deleteCartItem(int id) async {
    final db = await database;
    try {
      return await db.delete(tableCartItems, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Error deleting cart item: $e');
      return 0;
    }
  }

  // Clear all cart items
  Future<int> clearCart() async {
    final db = await database;
    try {
      return await db.delete(tableCartItems);
    } catch (e) {
      print('Error clearing cart: $e');
      return 0;
    }
  }

  // Clear all orders for a specific user
  Future<int> clearOrdersForUser(String userId) async {
    final db = await database;
    try {
      print('Clearing all orders for user $userId');
      return await db.delete(
        tableOrders,
        where: 'userId = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error clearing orders for user: $e');
      return 0;
    }
  }

  // Reset database completely - with better locking and error handling
  Future<void> resetDatabase() async {
    try {
      final path = join(await getDatabasesPath(), 'medcare.db');
      print('Attempting to delete database at: $path');

      // Close any open connection first
      if (_database != null) {
        await _database!.close();
        _database = null;
        print('Closed existing database connection');

        // Small delay to ensure connection is fully closed
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Delete the database file
      bool fileExists = await databaseExists(path);
      if (fileExists) {
        await deleteDatabase(path);
        print('Deleted existing database file');

        // Small delay to ensure file system operations complete
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        print('No database file found to delete');
      }

      // Reinitialize the database - with a small delay first
      await Future.delayed(const Duration(milliseconds: 500));
      _database = await _initDatabase();
      print('Database has been completely reset and reinitialized');
    } catch (e) {
      print('Error resetting database: $e');
      // Still set database to null to force recreation
      _database = null;
    }
  }

  // Medicine Methods

  // Get all medicines from database
  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(tableMedicines);
      return List.generate(maps.length, (i) => Medicine.fromJson(maps[i]));
    } catch (e) {
      print('Error getting all medicines: $e');
      return [];
    }
  }

  // Get medicines by category
  Future<List<Medicine>> getMedicinesByCategory(String category) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableMedicines,
        where: 'category = ?',
        whereArgs: [category],
      );
      return List.generate(maps.length, (i) => Medicine.fromJson(maps[i]));
    } catch (e) {
      print('Error getting medicines by category: $e');
      return [];
    }
  }

  // Get featured medicines
  Future<List<Medicine>> getFeaturedMedicines() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableMedicines,
        where: 'featured = ?',
        whereArgs: [1], // In SQLite, true is represented as 1
      );
      return List.generate(maps.length, (i) => Medicine.fromJson(maps[i]));
    } catch (e) {
      print('Error getting featured medicines: $e');
      return [];
    }
  }

  // Get a medicine by ID
  Future<Medicine?> getMedicineById(int id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        tableMedicines,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      return Medicine.fromJson(maps.first);
    } catch (e) {
      print('Error getting medicine by ID: $e');
      return null;
    }
  }

  // Insert a medicine record
  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    try {
      return await db.insert(
        tableMedicines,
        medicine.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting medicine: $e');
      return -1;
    }
  }

  // Force update an order (deletes and reinserts to ensure clean state)
  Future<void> forceUpdateOrder(Order order) async {
    final db = await database;

    try {
      // Use a transaction to ensure atomicity
      await db.transaction((txn) async {
        // First delete existing order and all its items
        await txn.delete(
          tableOrderItems,
          where: 'orderId = ?',
          whereArgs: [order.id],
        );

        await txn.delete(tableOrders, where: 'id = ?', whereArgs: [order.id]);

        // Then insert the new order
        print(
          'Force inserting order with ID: ${order.id}, address: ${order.address}, payment: ${order.paymentMethod}',
        );

        await txn.insert(tableOrders, {
          'id': order.id,
          'userId': order.userId,
          'totalAmount': order.totalAmount,
          'status': order.status,
          'address': order.address,
          'paymentMethod': order.paymentMethod,
          'notes': order.notes,
          'createdAt': order.createdAt.toIso8601String(),
          'updatedAt': order.updatedAt?.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Insert all order items
        for (var item in order.items) {
          await txn.insert(tableOrderItems, {
            // Remove the 'id' field since OrderItem doesn't have this property
            'orderId': order.id,
            'medicineId': item.medicineId,
            'medicineName': item.medicineName,
            'quantity': item.quantity,
            'price': item.price,
            'medicineImage': item.medicineImage,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      print('Order successfully force updated in database');
    } catch (e) {
      print('Error force updating order: $e');
      throw Exception('Failed to update order in database: $e');
    }
  }
}
