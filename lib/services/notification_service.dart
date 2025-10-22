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
      
      String? payload;
      final data = message.data;
      
      if (data.containsKey('senderId') && data.containsKey('receiverId')) {
        payload = 'chat_${data['senderId']}_${data['receiverId']}';
      } else if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
        payload = 'chat_${data['sender_id']}_${data['receiver_id']}';
      } else if (title.contains('|') && title.split('|').length >= 3) {
        final parts = title.split('|');
        final senderId = parts[1];
        final receiverId = parts[2];
        payload = 'chat_${senderId}_${receiverId}';
      }
      
      ByteArrayAndroidBitmap? largeIcon;
      BigPictureStyleInformation? styleInformation;
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          largeIcon = await _getImageBytes(imageUrl);
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: title,
            summaryText: body,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
        } catch (e) {
        }
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
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('chat_')) {
      _handleChatNotificationTap(payload);
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    if (data.containsKey('senderId') && data.containsKey('receiverId')) {
      await _handleChatNotificationTap('chat_${data['senderId']}_${data['receiverId']}');
    } else if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
      await _handleChatNotificationTap('chat_${data['sender_id']}_${data['receiver_id']}');
    } else {
      final title = message.notification?.title ?? '';
      if (title.contains('|') && title.split('|').length >= 3) {
        final parts = title.split('|');
        final senderId = parts[1];
        final receiverId = parts[2];
        await _handleChatNotificationTap('chat_${senderId}_${receiverId}');
      }
    }
  }

  Future<void> _handleChatNotificationTap(String payload) async {
    try {
      final parts = payload.split('_');
      if (parts.length >= 3) {
        final senderId = parts[1];
        final receiverId = parts[2];
        
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .get();
        
        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          final sender = AppUser.fromMap(senderData);
          
          NavigationService.instance.navigateToChat(
            senderId: sender.uid,
            receiverId: sender.uid,
          );
        }
      }
    } catch (e) {
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
      
      await _showLocalNotification(mockMessage);
    } catch (e) {
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
      final titleWithIds = '$senderName|$senderId|$receiverId';
      
      final payload = {
        'title': titleWithIds,
        'message': messageText,
        'token': receiverToken,
        'image': imageUrl,
        'data': {
          'senderId': senderId,
          'receiverId': receiverId,
          'type': 'chat',
          'imageUrl': imageUrl,
        },
      };

      final response = await http.post(
        Uri.parse('https://staging.hourandmore.sa/api/send-fcm-notification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
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
          largeIcon = await _getImageBytes(imageUrl);
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: senderName,
            summaryText: messageText,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
        } catch (e) {
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
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        senderName,
        messageText,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
    }
  }

  Future<ByteArrayAndroidBitmap> _getImageBytes(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        if (response.bodyBytes.isNotEmpty) {
          return ByteArrayAndroidBitmap(response.bodyBytes);
        } else {
          throw Exception('Image response is empty');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }
}