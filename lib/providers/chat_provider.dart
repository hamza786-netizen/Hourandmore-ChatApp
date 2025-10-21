import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService.instance;
  final FirebaseService _firebaseService = FirebaseService.instance;

  List<Message> _messages = [];
  String? _errorMessage;
  bool _isOnline = true;

  List<Message> get messages => _messages;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _isOnline;

  Future<void> sendMessage({
    required String text,
    required String senderId,
    required String senderEmail,
    required String receiverId,
    String? receiverToken,
  }) async {
    try {
      final message = Message(
        text: text,
        senderId: senderId,
        senderEmail: senderEmail,
        receiverId: receiverId,
        timestamp: DateTime.now(),
      );

      await _chatService.sendMessage(message);
      
      if (receiverToken != null) {
        await _chatService.sendMessageNotification(message, receiverToken);
      }
      
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadConversationMessages(String userId1, String userId2) async {
    try {
      _messages = await _chatService.getConversationMessages(userId1, userId2);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load messages: $e';
      _messages = [];
      notifyListeners();
    }
  }

  Stream<List<Message>> streamConversationMessages(
    String userId1,
    String userId2,
  ) {
    return _firebaseService.streamConversationMessages(userId1, userId2);
  }

  Future<void> handleIncomingMessage(Message message, String currentUserId) async {
    try {
      await _chatService.handleIncomingMessage(message, currentUserId);
    } catch (e) {
      _errorMessage = 'Failed to handle incoming message: $e';
      notifyListeners();
    }
  }

  Future<void> deleteAllMessages() async {
    try {
      await _chatService.deleteAllMessages();
      _messages = [];
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete messages: $e';
      notifyListeners();
    }
  }

  Future<void> deleteConversationMessages(String userId1, String userId2) async {
    try {
      await _chatService.deleteConversationMessages(userId1, userId2);
      _messages = [];
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete messages: $e';
      notifyListeners();
    }
  }

  Future<void> syncMessages() async {
    try {
      await _chatService.syncToFirebase();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sync messages: $e';
      notifyListeners();
    }
  }

  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}