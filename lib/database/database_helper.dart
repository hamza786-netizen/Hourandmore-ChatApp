import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebaseId TEXT,
        text TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderEmail TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isRead INTEGER DEFAULT 0,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sender ON messages(senderId)
    ''');

    await db.execute('''
      CREATE INDEX idx_receiver ON messages(receiverId)
    ''');

    await db.execute('''
      CREATE INDEX idx_timestamp ON messages(timestamp)
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS messages');
      await _createDB(db, newVersion);
    }
  }

  Future<int> insertMessage(Message message) async {
    final db = await database;
    return await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final result = await db.query(
      'messages',
      orderBy: 'timestamp ASC',
    );

    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getConversationMessages(
    String userId1,
    String userId2,
  ) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );

    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getMessagesBySender(String senderId) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'senderId = ?',
      whereArgs: [senderId],
      orderBy: 'timestamp ASC',
    );

    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<List<Message>> getUnsyncedMessages() async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );

    return result.map((map) => Message.fromMap(map)).toList();
  }

  Future<int> updateMessageSyncStatus(int id, bool synced) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isSynced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateMessageByFirebaseId(String firebaseId, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'messages',
      updates,
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
    );
  }

  Future<int> markMessageAsRead(int id) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMessage(int id) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllMessages() async {
    final db = await database;
    return await db.delete('messages');
  }

  Future<int> deleteConversationMessages(String userId1, String userId2) async {
    final db = await database;
    return await db.delete(
      'messages',
      where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}