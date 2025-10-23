import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../services/navigation_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;
  NotificationService._internal();
  
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _requestPermissions();
    await _getFcmToken();
    _setupMessageHandlers();
    
    // Test image URL accessibility
    await _testImageUrl();
  }
  
  Future<void> _testImageUrl() async {
    const testImageUrl = 'https://via.placeholder.com/300x200/6C63FF/FFFFFF?text=Chat';
    try {
      print('Testing image URL accessibility...');
      final response = await http.get(Uri.parse(testImageUrl));
      print('Test image URL status: ${response.statusCode}');
      print('Test image content type: ${response.headers['content-type']}');
      print('Test image size: ${response.bodyBytes.length} bytes');
      
      // Test creating a ByteArrayAndroidBitmap
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        try {
          final bitmap = ByteArrayAndroidBitmap(response.bodyBytes);
          print('ByteArrayAndroidBitmap created successfully');
        } catch (e) {
          print('Failed to create ByteArrayAndroidBitmap: $e');
        }
      }
    } catch (e) {
      print('Test image URL failed: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
      await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
      const androidChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Messages',
      description: 'Notifications for new chat messages',
        importance: Importance.high,
      enableVibration: true,
      playSound: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      await _saveFcmToken(_fcmToken);
    } catch (e) {
    }
  }

  Future<void> _saveFcmToken(String? token) async {
    if (token != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      } catch (e) {
      }
    }
  }

  Future<String?> getFcmToken() async {
    if (_fcmToken != null) return _fcmToken;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _fcmToken = prefs.getString('fcm_token');
      return _fcmToken;
    } catch (e) {
      return null;
    }
  }

  String? get fcmToken => _fcmToken;

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? 'New Message';
      final body = message.notification?.body ?? 'You have a new notification';
      final imageUrl = message.notification?.android?.imageUrl ?? 
                      message.data['image'] ?? 
                      message.data['imageUrl'] ??
                      message.data['image_url'];
      
      print('=== FOREGROUND NOTIFICATION RECEIVED ===');
      print('📱 Title: $title');
      print('📝 Body: $body');
      print('🖼️ Image URL: $imageUrl');
      print('📦 Raw Data: ${message.data}');
      print('🔍 Data Keys: ${message.data.keys.toList()}');
      
      String? payload;
      final data = message.data;
      
      print('🔍 Checking for sender/receiver data...');
      if (data.containsKey('senderId') && data.containsKey('receiverId')) {
        payload = 'chat_${data['senderId']}_${data['receiverId']}';
        print('✅ Found senderId and receiverId in data');
        print('   SenderId: ${data['senderId']}');
        print('   ReceiverId: ${data['receiverId']}');
        print('   Generated Payload: $payload');
      } else if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
        payload = 'chat_${data['sender_id']}_${data['receiver_id']}';
        print('✅ Found sender_id and receiver_id in data');
        print('   SenderId: ${data['sender_id']}');
        print('   ReceiverId: ${data['receiver_id']}');
        print('   Generated Payload: $payload');
      } else if (title.contains('|') && title.split('|').length >= 3) {
        final parts = title.split('|');
        final senderId = parts[1];
        final receiverId = parts[2];
        payload = 'chat_${senderId}_${receiverId}';
        print('✅ Found UID format in title');
        print('   Title parts: $parts');
        print('   SenderId: $senderId');
        print('   ReceiverId: $receiverId');
        print('   Generated Payload: $payload');
      } else {
        print('❌ No valid sender/receiver data found');
        print('   Available data keys: ${data.keys.toList()}');
        print('   Title format check: ${title.contains('|') ? 'Contains |' : 'No | found'}');
        if (title.contains('|')) {
          print('   Title parts count: ${title.split('|').length}');
        }
      }
      
      ByteArrayAndroidBitmap? largeIcon;
      BigPictureStyleInformation? styleInformation;
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        print('Attempting to load image: $imageUrl');
        try {
          largeIcon = await _getImageBytes(imageUrl);
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: title,
            summaryText: body,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
          print('✅ Image loaded successfully for foreground notification');
            } catch (e) {
          print('❌ Error loading image for foreground notification: $e');
        }
      } else {
        print('No image URL provided for foreground notification');
      }
      
      final androidDetails = AndroidNotificationDetails(
        'fcm_channel',
        'FCM Notifications',
        channelDescription: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        largeIcon: largeIcon,
        styleInformation: styleInformation ?? BigTextStyleInformation(
          body,
          contentTitle: title,
          htmlFormatContentTitle: true,
          htmlFormatBigText: true,
        ),
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      print('Creating notification with:');
      print('- Large icon: ${largeIcon != null ? 'Present' : 'Not present'}');
      print('- Style information: ${styleInformation != null ? 'Present' : 'Not present'}');
      print('- Image URL: $imageUrl');
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ Foreground notification created successfully');
    } catch (e) {
      print('❌ Error creating foreground notification: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('=== LOCAL NOTIFICATION TAPPED ===');
    print('📱 Payload: ${response.payload}');
    print('🔍 Action ID: ${response.actionId}');
    print('📝 Input: ${response.input}');
    
    final payload = response.payload;
    if (payload != null && payload.startsWith('chat_')) {
      print('✅ Valid chat payload found, processing...');
      _handleChatNotificationTap(payload);
    } else {
      print('❌ Invalid or missing payload');
      print('   Payload: $payload');
      print('   Starts with chat_: ${payload?.startsWith('chat_') ?? false}');
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('=== FCM NOTIFICATION TAPPED ===');
    print('📱 Title: ${message.notification?.title}');
    print('📝 Body: ${message.notification?.body}');
    print('📦 Data: ${message.data}');
    print('🔍 Data Keys: ${message.data.keys.toList()}');
    
    final data = message.data;
    
    if (data.containsKey('senderId') && data.containsKey('receiverId')) {
      print('✅ Found senderId and receiverId in data');
      print('   SenderId: ${data['senderId']}');
      print('   ReceiverId: ${data['receiverId']}');
      final payload = 'chat_${data['senderId']}_${data['receiverId']}';
      print('   Generated Payload: $payload');
      await _handleChatNotificationTap(payload);
    } else if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
      print('✅ Found sender_id and receiver_id in data');
      print('   SenderId: ${data['sender_id']}');
      print('   ReceiverId: ${data['receiver_id']}');
      final payload = 'chat_${data['sender_id']}_${data['receiver_id']}';
      print('   Generated Payload: $payload');
      await _handleChatNotificationTap(payload);
    } else {
      final title = message.notification?.title ?? '';
      print('🔍 Checking title for UID format: $title');
      if (title.contains('|') && title.split('|').length >= 3) {
        final parts = title.split('|');
        final senderId = parts[1];
        final receiverId = parts[2];
        print('✅ Found UID format in title');
        print('   Title parts: $parts');
        print('   SenderId: $senderId');
        print('   ReceiverId: $receiverId');
        final payload = 'chat_${senderId}_${receiverId}';
        print('   Generated Payload: $payload');
        await _handleChatNotificationTap(payload);
      } else {
        print('❌ No valid sender/receiver data found in notification');
        print('   Available data keys: ${data.keys.toList()}');
        print('   Title format check: ${title.contains('|') ? 'Contains |' : 'No | found'}');
        if (title.contains('|')) {
          print('   Title parts count: ${title.split('|').length}');
        }
      }
    }
  }

  Future<void> _handleChatNotificationTap(String payload) async {
    print('=== PROCESSING CHAT NOTIFICATION TAP ===');
    print('📱 Payload: $payload');
    
    try {
      final parts = payload.split('_');
      print('🔍 Payload parts: $parts');
      print('🔍 Parts count: ${parts.length}');
      
      if (parts.length >= 3) {
        final senderId = parts[1];
        final receiverId = parts[2];
        
        print('✅ Extracted IDs from payload:');
        print('   SenderId: $senderId');
        print('   ReceiverId: $receiverId');
        print('🚀 Navigating to chat...');
        
        // Navigate to chat with the sender (person who sent the message)
        await NavigationService.instance.navigateToChat(
          senderId: senderId,
          receiverId: receiverId,
        );
        
        print('✅ Navigation request sent successfully');
      } else {
        print('❌ Invalid payload format - not enough parts');
        print('   Expected format: chat_senderId_receiverId');
        print('   Actual parts: $parts');
      }
    } catch (e) {
      print('❌ Error handling chat notification tap: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> refreshFcmToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      await _getFcmToken();
    } catch (e) {
    }
  }

  Future<void> clearFcmToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
    } catch (e) {
    }
  }

  Future<void> testLocalNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'fcm_channel',
        'FCM Notifications',
        channelDescription: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        999,
        'Test Notification',
        'This is a test notification to verify local notifications work!',
        notificationDetails,
      );
    } catch (e) {
    }
  }

  Future<void> testHourAndMoreImageNotification() async {
    try {
      const imageUrl = 'https://hourandmore.com/images/noti.png';
      
      await showChatNotification(
        senderName: 'HourAndMore',
        messageText: 'Check out this notification with image!',
        senderId: 'test123',
        receiverId: 'test456',
        imageUrl: imageUrl,
      );
    } catch (e) {
    }
  }

  Future<void> testFcmMessageWithImage() async {
    try {
      const imageUrl = 'https://hourandmore.com/images/noti.png';
      
      final mockMessage = RemoteMessage(
        data: {
          'image': imageUrl,
          'imageUrl': imageUrl,
          'senderId': 'test123',
          'receiverId': 'test456',
          'type': 'chat',
        },
        notification: RemoteNotification(
          title: 'HourAndMore',
          body: 'Check out this FCM notification with image!',
          android: AndroidNotification(
            imageUrl: imageUrl,
            channelId: 'fcm_channel',
          ),
        ),
      );
      
      print('🧪 Testing FCM message with image in foreground...');
      await _showLocalNotification(mockMessage);
    } catch (e) {
      print('❌ Error in testFcmMessageWithImage: $e');
    }
  }

  Future<void> testImageLoading() async {
    try {
      const imageUrl = 'https://hourandmore.com/images/noti.png';
      print('🧪 Testing image loading: $imageUrl');
      
      final bitmap = await _getImageBytes(imageUrl);
      print('✅ Image loaded successfully, bitmap created');
    } catch (e) {
      print('❌ Image loading failed: $e');
    }
  }

  Future<bool> checkNotificationPermissions() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
      return isAuthorized;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendChatNotification({
    required String receiverToken,
    required String senderName,
    required String messageText,
    required String senderId,
    required String receiverId,
    String? imageUrl,
  }) async {
    try {
      final payload = {
        'title': senderName,
        'message': messageText,
        'token': receiverToken,
        'data': {
          'type': 'chat',
          'senderId': senderId,
          'receiverId': receiverId,
          'senderEmail': senderName,
          'chatType': 'direct_message',
        },
      };
      
      print('🚀 Sending Push Notification:');
      print('📱 API URL: https://staging.hourandmore.sa/api/send-fcm-notification');
      print('📦 Payload:');
      print('   Title: ${payload['title']}');
      print('   Message: ${payload['message']}');
      print('   Token: ${payload['token']}');
      print('   Data:');
      final data = payload['data'] as Map<String, dynamic>;
      print('     Type: ${data['type']}');
      print('     SenderId: ${data['senderId']}');
      print('     ReceiverId: ${data['receiverId']}');
      print('     SenderEmail: ${data['senderEmail']}');
      print('     ChatType: ${data['chatType']}');
      print('📄 Full JSON Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse('https://staging.hourandmore.sa/api/send-fcm-notification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ Push notification sent successfully!');
      } else {
        print('❌ Push notification failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  Future<void> showChatNotification({
    required String senderName,
    required String messageText,
    required String senderId,
    required String receiverId,
    String? imageUrl,
  }) async {
    try {
      ByteArrayAndroidBitmap? largeIcon;
      BigPictureStyleInformation? styleInformation;
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          print('Attempting to load image from: $imageUrl');
          largeIcon = await _getImageBytes(imageUrl);
          print('Image loaded successfully');
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: senderName,
            summaryText: messageText,
            htmlFormatContentTitle: false,
            htmlFormatSummaryText: false,
            largeIcon: largeIcon,
          );
        } catch (e) {
          print('Failed to load image: $e');
          // Try with a different image URL as fallback
          try {
            const fallbackImageUrl = 'https://picsum.photos/300/200';
            print('Trying fallback image URL: $fallbackImageUrl');
            largeIcon = await _getImageBytes(fallbackImageUrl);
            print('Fallback image loaded successfully');
            styleInformation = BigPictureStyleInformation(
              largeIcon,
              contentTitle: senderName,
              summaryText: messageText,
              htmlFormatContentTitle: false,
              htmlFormatSummaryText: false,
              largeIcon: largeIcon,
            );
          } catch (fallbackError) {
            print('Fallback image also failed: $fallbackError');
            // Continue without image
          }
        }
      }
      
      final androidDetails = AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.message,
        largeIcon: largeIcon,
        styleInformation: styleInformation ?? BigTextStyleInformation(
          messageText,
          contentTitle: senderName,
          htmlFormatContentTitle: true,
          htmlFormatBigText: true,
        ),
        // Ensure the notification can display images
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'chat_message',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final payload = 'chat_${senderId}_${receiverId}';
      
      print('📱 Creating Local Notification:');
      print('   Sender: $senderName');
      print('   Message: $messageText');
      print('   SenderId: $senderId');
      print('   ReceiverId: $receiverId');
      print('   Payload: $payload');
      print('   Image URL: ${imageUrl ?? 'None'}');
      print('   Large icon: ${largeIcon != null ? 'Present' : 'Not present'}');
      print('   Style information: ${styleInformation != null ? 'Present' : 'Not present'}');
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        senderName,
        messageText,
        notificationDetails,
        payload: payload,
      );
      
      print('Notification created successfully');
    } catch (e) {
    }
  }

  Future<ByteArrayAndroidBitmap> _getImageBytes(String imageUrl) async {
    try {
      print('Making HTTP request to: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      print('HTTP response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body length: ${response.bodyBytes.length}');
      
      if (response.statusCode == 200) {
        if (response.bodyBytes.isNotEmpty) {
          print('Image downloaded successfully');
          return ByteArrayAndroidBitmap(response.bodyBytes);
        } else {
          throw Exception('Image response is empty');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error in _getImageBytes: $e');
      throw Exception('Failed to load image: $e');
    }
  }
}