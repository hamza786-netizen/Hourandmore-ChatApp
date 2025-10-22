import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../screens/chat_screen.dart';

class NavigationService {
  static final NavigationService instance = NavigationService._init();
  NavigationService._init();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Store pending navigation requests when app is starting up
  Map<String, String>? _pendingNavigation;

  BuildContext? get currentContext => navigatorKey.currentContext;

  Future<void> navigateToChat({
    required String senderId,
    required String receiverId,
  }) async {
    debugPrint('NavigationService: navigateToChat called with senderId: $senderId, receiverId: $receiverId');
    
    // Wait longer when app is starting up to ensure the app is fully initialized
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final context = currentContext;
    if (context == null) {
      debugPrint('NavigationService: No context available after delay');
      // Try again after a longer delay
      await Future.delayed(const Duration(milliseconds: 2000));
      final context2 = currentContext;
      if (context2 == null) {
        debugPrint('NavigationService: Still no context available - storing pending navigation');
        // Store the navigation request for later processing
        _pendingNavigation = {
          'senderId': senderId,
          'receiverId': receiverId,
        };
        return;
      }
    }

    try {
      debugPrint('NavigationService: Fetching user data for senderId: $senderId');
      
      // Get the sender's user data from Firestore
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();

      if (!senderDoc.exists) {
        debugPrint('NavigationService: Sender user not found: $senderId');
        return;
      }

      final senderData = senderDoc.data()!;
      final senderUser = AppUser.fromMap(senderData);
      
      debugPrint('NavigationService: User data fetched successfully: ${senderUser.displayName}');

      // Navigate to chat screen
      final finalContext = currentContext;
      if (finalContext != null && finalContext.mounted) {
        debugPrint('NavigationService: Navigating to chat screen');
        Navigator.of(finalContext).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(receiverUser: senderUser),
          ),
        );
        debugPrint('NavigationService: Navigation completed');
      } else {
        debugPrint('NavigationService: Context not available or not mounted');
      }
    } catch (e) {
      debugPrint('NavigationService: Error navigating to chat: $e');
    }
  }

  Future<void> handleChatNotificationTap(String? payload) async {
    debugPrint('NavigationService: handleChatNotificationTap called with payload: $payload');
    
    if (payload == null || !payload.startsWith('chat_')) {
      debugPrint('NavigationService: Invalid payload format');
      return;
    }

    // Parse payload: chat_senderId_receiverId
    final parts = payload.split('_');
    if (parts.length != 3) {
      debugPrint('NavigationService: Invalid chat notification payload format: $payload');
      return;
    }

    final senderId = parts[1];
    final receiverId = parts[2];
    
    debugPrint('NavigationService: Parsed senderId: $senderId, receiverId: $receiverId');

    await navigateToChat(
      senderId: senderId,
      receiverId: receiverId,
    );
  }

  // Method to process pending navigation requests when app becomes ready
  Future<void> processPendingNavigation() async {
    if (_pendingNavigation != null) {
      debugPrint('NavigationService: Processing pending navigation: $_pendingNavigation');
      final senderId = _pendingNavigation!['senderId']!;
      final receiverId = _pendingNavigation!['receiverId']!;
      _pendingNavigation = null; // Clear the pending request
      
      // Wait a bit more to ensure the app is fully ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      await navigateToChat(
        senderId: senderId,
        receiverId: receiverId,
      );
    }
  }

  // Method to check if there's a pending navigation request
  bool get hasPendingNavigation => _pendingNavigation != null;
}
