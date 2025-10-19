import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const String _tokenKey = 'fcm_token';
  
  String? _fcmToken;
  
  NotificationService._init();

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();
      
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        await _saveFcmToken(_fcmToken!);
      }

      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
      });

      _setupMessageHandlers();
    } catch (e) {
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
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
      
      await _localNotifications.initialize(initSettings);
      
      await _createNotificationChannel();
      await _createChatNotificationChannel();
      
    } catch (e) {
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        'fcm_channel',
        'FCM Notifications',
        description: 'Notifications from Firebase Cloud Messaging',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
    } catch (e) {
    }
  }

  Future<void> _createChatNotificationChannel() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        'chat_channel',
        'Chat Messages',
        description: 'Notifications for new chat messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF6C63FF),
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
    } catch (e) {
    }
  }

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
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
    }
  }

  Future<String?> getSavedFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFcmToken() async {
    try {
      await _fcm.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _fcmToken = null;
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
      
      const notificationDetails = NotificationDetails(
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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://staging.hourandmore.sa/api/send-fcm-notification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': senderName,
          'message': messageText,
          'token': receiverToken,
        }),
      );
    } catch (e) {
    }
  }

  Future<void> showChatNotification({
    required String senderName,
    required String messageText,
    required String senderId,
    required String receiverId,
  }) async {
    try {
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
      );
      
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'CHAT_MESSAGE',
        threadIdentifier: 'chat_$senderId',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final notificationId = '$senderId-$receiverId'.hashCode;
      
      await _localNotifications.show(
        notificationId,
        senderName,
        messageText,
        notificationDetails,
        payload: 'chat_${senderId}_$receiverId',
      );
    } catch (e) {
    }
  }

  void setupNotificationActionHandlers() {
    _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'reply' && response.input != null) {
          _handleReplyAction(response.payload, response.input!);
        } else if (response.actionId == 'mark_read') {
          _handleMarkAsReadAction(response.payload);
        } else {
          _handleChatNotificationTap(response.payload);
        }
      },
    );
  }

  void _handleReplyAction(String? payload, String input) {
  }

  void _handleMarkAsReadAction(String? payload) {
  }

  void _handleChatNotificationTap(String? payload) {
  }
}