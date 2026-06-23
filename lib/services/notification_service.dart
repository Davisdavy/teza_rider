import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background isolate
  await Firebase.initializeApp();
  debugPrint("Background message received: ${message.messageId} - ${message.data}");
}

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService instance = NotificationService._privateConstructor();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  final StreamController<String> _notificationClickController = StreamController<String>.broadcast();
  Stream<String> get onNotificationClick => _notificationClickController.stream;

  final StreamController<Map<String, dynamic>> _notificationReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationReceived => _notificationReceivedController.stream;

  final StreamController<String> _tokenRefreshController = StreamController<String>.broadcast();
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Local Notifications Initialization (specifically for custom sounds)
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          _notificationClickController.add(payload);
        }
      },
    );

    // 3. Configure Android sound channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'offer_channel', // id
      'Delivery Offers', // title
      description: 'This channel is used for delivery offers.', // description
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('offer_alert_bell'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Configure FCM Foreground Options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      sound: true,
      badge: true,
    );

    // 5. Setup foreground messaging stream listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.messageId}");
      
      final type = message.data['type'] ?? 'NOTIFICATION';
      final offerId = message.data['offerId'];
      
      final payloadMap = {
        'type': type,
        'offerId': offerId,
        'title': message.notification?.title,
        'body': message.notification?.body,
      };

      if (type == 'OFFER') {
        // For offers in the foreground, do NOT show a local notification banner.
        // This avoids double alert sounds and cluttering the status bar while the app is active.
        _notificationReceivedController.add(payloadMap);
      } else {
        // For other statuses, show the local notification banner
        _showLocalNotification(message);
        _notificationReceivedController.add(payloadMap);
      }
    });

    // 6. Setup click listener when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM message clicked from background: ${message.messageId}");
      final type = message.data['type'] ?? 'NOTIFICATION';
      final offerId = message.data['offerId'];
      _notificationClickController.add(jsonEncode({
        'type': type,
        'offerId': offerId,
      }));
    });

    // 7. Setup token refresh stream listener
    _fcm.onTokenRefresh.listen((String token) {
      debugPrint("FCM token refreshed: $token");
      _tokenRefreshController.add(token);
    });
  }

  Future<bool> requestPermissions() async {
    // Request permission for Firebase Messaging
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request permission for Android local notifications if needed
    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("Error fetching FCM device token: $e");
      return null;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    
    if (notification != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'offer_channel',
        'Delivery Offers',
        channelDescription: 'This channel is used for delivery offers.',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('offer_alert_bell'),
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'offer_alert_bell.mp3',
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode & 0x7FFFFFFF, // Ensure the notification ID is a positive integer to prevent Android crashes
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode({
          'type': message.data['type'] ?? 'NOTIFICATION',
          'offerId': message.data['offerId'],
        }),
      );
    }
  }
}
