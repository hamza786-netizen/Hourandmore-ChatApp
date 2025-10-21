import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'navigation_service.dart';

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
      
      await _fcm.requestPermission(
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
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('=== NOTIFICATION RESPONSE RECEIVED ===');
          debugPrint('NotificationService: Action ID: ${response.actionId}');
          debugPrint('NotificationService: Payload: ${response.payload}');
          debugPrint('NotificationService: Input: ${response.input}');
          debugPrint('NotificationService: Notification ID: ${response.id}');
          debugPrint('NotificationService: Notification Title: ${response.notificationResponseType}');
          debugPrint('=====================================');
          
          if (response.actionId == 'reply' && response.input != null) {
            _handleReplyAction(response.payload, response.input!);
          } else if (response.actionId == 'mark_read') {
            _handleMarkAsReadAction(response.payload);
          } else {
            _handleChatNotificationTap(response.payload);
          }
        },
      );
      
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
      debugPrint('=== FCM ON MESSAGE RECEIVED ===');
      debugPrint('NotificationService: Message ID: ${message.messageId}');
      debugPrint('NotificationService: Message Type: ${message.messageType}');
      debugPrint('NotificationService: From: ${message.from}');
      debugPrint('NotificationService: Data: ${message.data}');
      debugPrint('NotificationService: Data Keys: ${message.data.keys}');
      debugPrint('NotificationService: Notification Title: ${message.notification?.title}');
      debugPrint('NotificationService: Notification Body: ${message.notification?.body}');
      debugPrint('NotificationService: Android Image URL: ${message.notification?.android?.imageUrl}');
      debugPrint('NotificationService: Sent Time: ${message.sentTime}');
      debugPrint('================================');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('=== FCM ON MESSAGE OPENED APP ===');
      debugPrint('NotificationService: Message ID: ${message.messageId}');
      debugPrint('NotificationService: Message Type: ${message.messageType}');
      debugPrint('NotificationService: From: ${message.from}');
      debugPrint('NotificationService: Data: ${message.data}');
      debugPrint('NotificationService: Data Keys: ${message.data.keys}');
      debugPrint('NotificationService: Notification Title: ${message.notification?.title}');
      debugPrint('NotificationService: Notification Body: ${message.notification?.body}');
      debugPrint('==================================');
      _handleNotificationTap(message);
    });

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('=== FCM GET INITIAL MESSAGE ===');
        debugPrint('NotificationService: Message ID: ${message.messageId}');
        debugPrint('NotificationService: Message Type: ${message.messageType}');
        debugPrint('NotificationService: From: ${message.from}');
        debugPrint('NotificationService: Data: ${message.data}');
        debugPrint('NotificationService: Data Keys: ${message.data.keys}');
        debugPrint('NotificationService: Notification Title: ${message.notification?.title}');
        debugPrint('NotificationService: Notification Body: ${message.notification?.body}');
        debugPrint('================================');
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
      
      debugPrint('=== CREATING LOCAL NOTIFICATION ===');
      debugPrint('NotificationService: Title: $title');
      debugPrint('NotificationService: Body: $body');
      debugPrint('NotificationService: Image URL: $imageUrl');
      debugPrint('NotificationService: Message data: ${message.data}');
      debugPrint('NotificationService: Message notification: ${message.notification}');
      
      // Create payload for chat notifications
      String? payload;
      final data = message.data;
      debugPrint('NotificationService: Data keys: ${data.keys}');
      debugPrint('NotificationService: Data values: ${data.values}');
      debugPrint('NotificationService: Data is empty: ${data.isEmpty}');
      
      // Log all data entries individually
      data.forEach((key, value) {
        debugPrint('NotificationService: Data entry - $key: $value (${value.runtimeType})');
      });
      
      if (data.containsKey('senderId') && data.containsKey('receiverId')) {
        payload = 'chat_${data['senderId']}_${data['receiverId']}';
        debugPrint('NotificationService: ✅ Created payload for local notification: $payload');
      } else {
        debugPrint('NotificationService: ❌ Missing senderId or receiverId in message data');
        debugPrint('NotificationService: Available keys: ${data.keys}');
        debugPrint('NotificationService: Checking for sender_id instead of senderId...');
        
        // Check for alternative key names
        if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
          payload = 'chat_${data['sender_id']}_${data['receiver_id']}';
          debugPrint('NotificationService: ✅ Created payload with alternative keys: $payload');
        } else {
          debugPrint('NotificationService: ❌ No valid sender/receiver keys found');
          debugPrint('NotificationService: All available keys: ${data.keys.toList()}');
          
          // Try to extract from any key that might contain user IDs
          for (final key in data.keys) {
            final value = data[key];
            debugPrint('NotificationService: Checking key "$key" with value "$value"');
            if (value is String && value.contains('_') && value.length > 10) {
              debugPrint('NotificationService: Potential user ID found in key "$key": "$value"');
            }
          }
          
          // TEMPORARY WORKAROUND: Extract user IDs from title since FCM data is not working
          if (title.isNotEmpty && title != 'New Message' && title.contains('|')) {
            debugPrint('NotificationService: Using title-based fallback: $title');
            try {
              final titleParts = title.split('|');
              if (titleParts.length >= 3) {
                final extractedSenderId = titleParts[1];
                final extractedReceiverId = titleParts[2];
                payload = 'chat_${extractedSenderId}_$extractedReceiverId';
                debugPrint('NotificationService: ✅ Extracted from title - senderId: $extractedSenderId, receiverId: $extractedReceiverId');
                debugPrint('NotificationService: ✅ Created payload from title: $payload');
              } else {
                debugPrint('NotificationService: ❌ Title format invalid: $title');
              }
            } catch (e) {
              debugPrint('NotificationService: ❌ Error parsing title: $e');
            }
          } else {
            debugPrint('NotificationService: ❌ Title does not contain user IDs: $title');
          }
        }
      }
      
      ByteArrayAndroidBitmap? largeIcon;
      BigPictureStyleInformation? styleInformation;
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('NotificationService: Attempting to load image: $imageUrl');
        try {
          largeIcon = await _getImageBytes(imageUrl);
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: title,
            summaryText: body,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
          debugPrint('NotificationService: ✅ Image loaded successfully for notification');
        } catch (e) {
          debugPrint('NotificationService: ❌ Error loading image for notification: $e');
          // Fall back to text notification if image fails to load
        }
      } else {
        debugPrint('NotificationService: No image URL provided, using text notification');
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
      
      debugPrint('NotificationService: Showing notification with ID: ${message.hashCode}');
      debugPrint('NotificationService: Payload being set: $payload');
      
      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      debugPrint('NotificationService: ✅ Local notification shown successfully');
      debugPrint('NotificationService: Final payload: $payload');
      debugPrint('=====================================');
    } catch (e) {
      debugPrint('NotificationService: ❌ Error showing local notification: $e');
      debugPrint('NotificationService: Stack trace: ${StackTrace.current}');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('=== FCM NOTIFICATION TAP HANDLED ===');
    debugPrint('NotificationService: Message ID: ${message.messageId}');
    debugPrint('NotificationService: Message data: ${message.data}');
    debugPrint('NotificationService: Data keys: ${message.data.keys}');
    debugPrint('NotificationService: Data values: ${message.data.values}');
    debugPrint('NotificationService: Notification title: ${message.notification?.title}');
    
    // Handle chat notifications
    final data = message.data;
    String? senderId;
    String? receiverId;
    
    if (data.containsKey('senderId') && data.containsKey('receiverId')) {
      senderId = data['senderId'];
      receiverId = data['receiverId'];
      debugPrint('NotificationService: ✅ Found senderId: $senderId, receiverId: $receiverId in data');
    } else if (data.containsKey('sender_id') && data.containsKey('receiver_id')) {
      senderId = data['sender_id'];
      receiverId = data['receiver_id'];
      debugPrint('NotificationService: ✅ Found alternative keys - sender_id: $senderId, receiver_id: $receiverId');
    } else {
      debugPrint('NotificationService: ❌ No valid sender/receiver keys found in data');
      
      // TEMPORARY WORKAROUND: Extract from notification title when app is closed
      final title = message.notification?.title ?? '';
      debugPrint('NotificationService: Checking notification title: $title');
      
      if (title.isNotEmpty && title.contains('|')) {
        debugPrint('NotificationService: Using title-based extraction for closed app');
        try {
          final titleParts = title.split('|');
          if (titleParts.length >= 3) {
            senderId = titleParts[1];
            receiverId = titleParts[2];
            debugPrint('NotificationService: ✅ Extracted from title - senderId: $senderId, receiverId: $receiverId');
          } else {
            debugPrint('NotificationService: ❌ Title format invalid: $title');
          }
        } catch (e) {
          debugPrint('NotificationService: ❌ Error parsing title: $e');
        }
      } else {
        debugPrint('NotificationService: ❌ Title does not contain user IDs: $title');
      }
    }
    
    // Navigate to chat screen if we have valid IDs
    if (senderId != null && receiverId != null) {
      debugPrint('NotificationService: ✅ Navigating to chat with senderId: $senderId, receiverId: $receiverId');
      NavigationService.instance.navigateToChat(
        senderId: senderId,
        receiverId: receiverId,
      );
    } else {
      debugPrint('NotificationService: ❌ Cannot navigate - missing sender or receiver ID');
    }
    
    debugPrint('====================================');
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

  // Test method for your specific image URL
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
      
      debugPrint('NotificationService: ✅ Test notification with HourAndMore image sent');
    } catch (e) {
      debugPrint('NotificationService: ❌ Error testing HourAndMore image notification: $e');
    }
  }

  // Test method to simulate FCM message with image
  Future<void> testFcmMessageWithImage() async {
    try {
      const imageUrl = 'https://hourandmore.com/images/noti.png';
      
      // Create a mock FCM message with image
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
      
      debugPrint('NotificationService: Testing FCM message with image: $imageUrl');
      await _showLocalNotification(mockMessage);
      debugPrint('NotificationService: ✅ FCM test notification with image sent');
    } catch (e) {
      debugPrint('NotificationService: ❌ Error testing FCM image notification: $e');
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
      // TEMPORARY WORKAROUND: Include user IDs in title since FCM data is not working
      final titleWithIds = '$senderName|$senderId|$receiverId';
      
      final payload = {
        'title': titleWithIds,
        'message': messageText,
        'token': receiverToken,
        'image': imageUrl, // Add image URL to payload
        'data': {
          'senderId': senderId,
          'receiverId': receiverId,
          'type': 'chat',
          'imageUrl': imageUrl, // Also include in data for FCM
        },
      };
      
      debugPrint('=== SENDING CHAT NOTIFICATION ===');
      debugPrint('NotificationService: Receiver Token: $receiverToken');
      debugPrint('NotificationService: Sender Name: $senderName');
      debugPrint('NotificationService: Message Text: $messageText');
      debugPrint('NotificationService: Image URL: $imageUrl');
      debugPrint('NotificationService: Sender ID: $senderId');
      debugPrint('NotificationService: Receiver ID: $receiverId');
      debugPrint('NotificationService: Full Payload: $payload');
      debugPrint('NotificationService: JSON Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse('https://staging.hourandmore.sa/api/send-fcm-notification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      debugPrint('NotificationService: ✅ FCM API Response Status: ${response.statusCode}');
      debugPrint('NotificationService: FCM API Response Headers: ${response.headers}');
      debugPrint('NotificationService: FCM API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        debugPrint('NotificationService: ✅ FCM API call successful');
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('NotificationService: FCM API Response Data: $responseData');
        } catch (e) {
          debugPrint('NotificationService: Could not parse FCM API response as JSON');
        }
      } else {
        debugPrint('NotificationService: ❌ FCM API call failed with status: ${response.statusCode}');
      }
      debugPrint('==================================');
    } catch (e) {
      debugPrint('NotificationService: ❌ Error sending chat notification: $e');
      debugPrint('NotificationService: Stack trace: ${StackTrace.current}');
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
        debugPrint('NotificationService: Attempting to load image for chat notification: $imageUrl');
        try {
          largeIcon = await _getImageBytes(imageUrl);
          styleInformation = BigPictureStyleInformation(
            largeIcon,
            contentTitle: senderName,
            summaryText: messageText,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
          debugPrint('NotificationService: ✅ Image loaded successfully for chat notification');
        } catch (e) {
          debugPrint('NotificationService: ❌ Error loading image for chat notification: $e');
          // Fall back to text notification if image fails to load
        }
      } else {
        debugPrint('NotificationService: No image URL provided for chat notification, using text');
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
    // This method is no longer needed as we handle notification responses
    // in the main initialization method
    debugPrint('NotificationService: setupNotificationActionHandlers called (no longer needed)');
  }

  void _handleReplyAction(String? payload, String input) {
  }

  void _handleMarkAsReadAction(String? payload) {
  }

  void _handleChatNotificationTap(String? payload) {
    debugPrint('=== LOCAL NOTIFICATION TAP HANDLED ===');
    debugPrint('NotificationService: Payload received: $payload');
    debugPrint('NotificationService: Payload type: ${payload.runtimeType}');
    debugPrint('NotificationService: Payload length: ${payload?.length ?? 0}');
    debugPrint('NotificationService: Payload is null: ${payload == null}');
    debugPrint('NotificationService: Payload is empty: ${payload?.isEmpty ?? true}');
    debugPrint('=====================================');
    NavigationService.instance.handleChatNotificationTap(payload);
  }

  // Test method to simulate notification tap
  Future<void> testNotificationNavigation({
    required String senderId,
    required String receiverId,
  }) async {
    debugPrint('NotificationService: Testing notification navigation');
    await NavigationService.instance.navigateToChat(
      senderId: senderId,
      receiverId: receiverId,
    );
  }

  // Test method to simulate local notification with payload
  Future<void> testLocalNotificationWithPayload({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String messageText,
  }) async {
    debugPrint('NotificationService: Testing local notification with payload');
    
    final payload = 'chat_${senderId}_$receiverId';
    debugPrint('NotificationService: Test payload: $payload');
    
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
      senderName,
      messageText,
      notificationDetails,
      payload: payload,
    );
    
    debugPrint('NotificationService: Test local notification shown with payload: $payload');
  }


  Future<ByteArrayAndroidBitmap> _getImageBytes(String imageUrl) async {
    try {
      debugPrint('NotificationService: Loading image from: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      debugPrint('NotificationService: Image response status: ${response.statusCode}');
      debugPrint('NotificationService: Image content length: ${response.bodyBytes.length} bytes');
      
      if (response.statusCode == 200) {
        if (response.bodyBytes.isNotEmpty) {
          debugPrint('NotificationService: ✅ Image loaded successfully');
          return ByteArrayAndroidBitmap(response.bodyBytes);
        } else {
          throw Exception('Image response is empty');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('NotificationService: ❌ Error loading image from $imageUrl: $e');
      throw Exception('Failed to load image: $e');
    }
  }
}