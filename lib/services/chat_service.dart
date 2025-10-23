import '../models/message.dart';
import '../database/database_helper.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class ChatService {
  static final ChatService instance = ChatService._init();
  
  final DatabaseHelper _localDb = DatabaseHelper.instance;
  final FirebaseService _firebaseService = FirebaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  ChatService._init();

  Future<void> sendMessage(Message message) async {
    final localId = await _localDb.insertMessage(message);
    
    try {
      final firebaseId = await _firebaseService.sendMessage(message);
      if (firebaseId != null) {
        await _localDb.updateMessageSyncStatus(localId, true);
        await _sendPushNotification(message);
      }
    } catch (e) {
    }
  }

  Stream<List<Message>> getMessagesStream() {
    return _firebaseService.getMessagesStream();
  }

  Stream<List<Message>> streamConversationMessages(
    String userId1,
    String userId2,
  ) {
    return _firebaseService.streamConversationMessages(userId1, userId2);
  }

  Future<List<Message>> getLocalMessages() async {
    return await _localDb.getAllMessages();
  }

  Future<void> handleIncomingMessage(Message message, String currentUserId) async {
    try {
      if (message.receiverId == currentUserId) {
        final senderName = message.senderEmail.split('@').first;
        
        await _notificationService.showChatNotification(
          senderName: senderName,
          messageText: message.text,
          senderId: message.senderId,
          receiverId: message.receiverId,
          imageUrl: 'https://hourandmore.com/images/noti.png',
        );
      }
    } catch (e) {
    }
  }

  Future<void> sendMessageNotification(Message message, String receiverToken) async {
    try {
      final senderName = message.senderEmail.split('@').first;
      
      await _notificationService.sendChatNotification(
        receiverToken: receiverToken,
        senderName: senderName,
        messageText: message.text,
        senderId: message.senderId,
        receiverId: message.receiverId,
        imageUrl: 'https://hourandmore.com/images/noti.png',
      );
    } catch (e) {
    }
  }

  Future<List<Message>> getConversationMessages(
    String userId1,
    String userId2,
  ) async {
    return await _localDb.getConversationMessages(userId1, userId2);
  }

  Future<void> deleteAllMessages() async {
    await _localDb.deleteAllMessages();
    
    try {
      await _firebaseService.deleteAllMessages();
    } catch (e) {
    }
  }

  Future<void> deleteConversationMessages(String userId1, String userId2) async {
    await _localDb.deleteConversationMessages(userId1, userId2);
    
    try {
      await _firebaseService.deleteConversationMessages(userId1, userId2);
    } catch (e) {
    }
  }

  Future<void> syncToFirebase() async {
    try {
      final unsyncedMessages = await _localDb.getUnsyncedMessages();
      
      for (var message in unsyncedMessages) {
        try {
          final firebaseId = await _firebaseService.sendMessage(message);
          if (firebaseId != null && message.id != null) {
            await _localDb.updateMessageSyncStatus(message.id!, true);
          }
        } catch (e) {
        }
      }
    } catch (e) {
    }
  }

  Future<void> syncFromFirebase(String userId1, String userId2) async {
    try {
      final firebaseMessages = await _firebaseService.getConversationMessages(
        userId1,
        userId2,
      );

      for (var message in firebaseMessages) {
        await _localDb.insertMessage(message.copyWith(isSynced: true));
      }
    } catch (e) {
    }
  }

  Future<void> _sendPushNotification(Message message) async {
    try {
      final receiverToken = await _firebaseService.getUserFcmToken(message.receiverId);
      
      if (receiverToken == null) {
        return;
      }

      final senderName = message.senderEmail.split('@').first;

      await _notificationService.sendChatNotification(
        receiverToken: receiverToken,
        senderName: senderName,
        messageText: message.text,
        senderId: message.senderId,
        receiverId: message.receiverId,
        imageUrl: 'https://hourandmore.com/images/noti.png',
      );
    } catch (e) {
    }
  }
}