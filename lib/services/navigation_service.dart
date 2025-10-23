import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../screens/chat_screen.dart';

class NavigationService {
  static final NavigationService instance = NavigationService._init();
  NavigationService._init();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  Map<String, String>? _pendingNavigation;

  BuildContext? get currentContext => navigatorKey.currentContext;

  Future<void> navigateToChat({
    required String senderId,
    required String receiverId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final context = currentContext;
    if (context == null) {
      await Future.delayed(const Duration(milliseconds: 2000));
      final context2 = currentContext;
      if (context2 == null) {
        _pendingNavigation = {
          'senderId': senderId,
          'receiverId': receiverId,
        };
        return;
      }
    }

    try {
      print('Navigating to chat - SenderId: $senderId, ReceiverId: $receiverId');
      
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();

      if (!senderDoc.exists) {
        print('Sender user not found: $senderId');
        return;
      }

      final senderData = senderDoc.data()!;
      final senderUser = AppUser.fromMap(senderData);
      print('Found sender user: ${senderUser.displayName}');

      final finalContext = currentContext;
      if (finalContext != null && finalContext.mounted) {
        print('Navigating to chat screen with: ${senderUser.displayName}');
        Navigator.of(finalContext).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(receiverUser: senderUser),
          ),
        );
      } else {
        print('Context not available for navigation');
      }
    } catch (e) {
      print('Error navigating to chat: $e');
    }
  }

  Future<void> handleChatNotificationTap(String? payload) async {
    if (payload == null || !payload.startsWith('chat_')) {
      return;
    }

    final parts = payload.split('_');
    if (parts.length != 3) {
      return;
    }

    final senderId = parts[1];
    final receiverId = parts[2];

    await navigateToChat(
      senderId: senderId,
      receiverId: receiverId,
    );
  }

  Future<void> processPendingNavigation() async {
    if (_pendingNavigation != null) {
      final senderId = _pendingNavigation!['senderId']!;
      final receiverId = _pendingNavigation!['receiverId']!;
      _pendingNavigation = null;
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      await navigateToChat(
        senderId: senderId,
        receiverId: receiverId,
      );
    }
  }

  bool get hasPendingNavigation => _pendingNavigation != null;
}
