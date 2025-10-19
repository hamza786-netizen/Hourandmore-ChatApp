import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/user.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final String _messagesCollection = 'messages';
  final String _usersCollection = 'users';

  FirebaseService._init();

  Future<String?> sendMessage(Message message) async {
    try {
      final messageData = message.toFirebaseMap();
      final docRef = await _firestore.collection(_messagesCollection).add(messageData);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Message>> getMessagesStream() {
    return _firestore
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Message.fromFirebaseMap(data, doc.id);
      }).toList();
    });
  }

  Stream<List<Message>> streamConversationMessages(
    String userId1,
    String userId2,
  ) {
    return _firestore
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final allMessages = snapshot.docs.map((doc) {
            final data = doc.data();
            return Message.fromFirebaseMap(data, doc.id);
          }).toList();
          
          final conversationMessages = allMessages.where((message) {
            final match = (message.senderId == userId1 && message.receiverId == userId2) ||
                         (message.senderId == userId2 && message.receiverId == userId1);
            return match;
          }).toList();
          
          return conversationMessages;
        });
  }

  Future<List<Message>> getConversationMessages(
    String userId1,
    String userId2,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Message.fromFirebaseMap(data, doc.id);
          })
          .where((message) =>
              (message.senderId == userId1 && message.receiverId == userId2) ||
              (message.senderId == userId2 && message.receiverId == userId1))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteAllMessages() async {
    try {
      final batch = _firestore.batch();
      final snapshots = await _firestore.collection(_messagesCollection).get();
      
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteConversationMessages(String userId1, String userId2) async {
    try {
      final batch = _firestore.batch();
      final snapshots = await _firestore
          .collection(_messagesCollection)
          .where('senderId', whereIn: [userId1, userId2])
          .get();

      for (var doc in snapshots.docs) {
        final data = doc.data();
        final message = Message.fromFirebaseMap(data, doc.id);
        if ((message.senderId == userId1 && message.receiverId == userId2) ||
            (message.senderId == userId2 && message.receiverId == userId1)) {
          batch.delete(doc.reference);
        }
      }
      
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection(_messagesCollection).doc(messageId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Message>> getAllMessages() async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Message.fromFirebaseMap(data, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection(_messagesCollection).doc(messageId).update({
        'isRead': true,
      });
    } catch (e) {
    }
  }

  Future<void> createOrUpdateUser(AppUser user) async {
    try {
      await _firestore.collection(_usersCollection).doc(user.uid).set(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserFcmToken(String uid, String fcmToken) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'fcmToken': fcmToken,
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getUserFcmToken(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection(_usersCollection).get();
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      rethrow;
    }
  }
}