import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Mensaje en background: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _requestPermissions();
    await _initializeLocalNotifications();
    
    // Escuchar cambios de autenticación para guardar token
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _getAndSaveToken();
      }
    });

    // Si ya hay usuario, guardar token
    if (_auth.currentUser != null) {
      await _getAndSaveToken();
    }

    _fcm.onTokenRefresh.listen((token) {
      _saveTokenToFirestore(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _initialized = true;
    debugPrint('✅ PushNotificationService inicializado');
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('📱 Permisos FCM: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    const channel = AndroidNotificationChannel(
      'habits_channel',
      'Recordatorios de Hábitos',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _getAndSaveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('🔑 FCM Token obtenido');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No hay usuario para guardar token');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Token FCM guardado para usuario: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error guardando token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Mensaje recibido: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habits_channel',
            'Recordatorios de Hábitos',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 Notificación abierta: ${message.data}');
  }

  // Método para probar notificación
  Future<void> sendTestNotification() async {
    await _localNotifications.show(
      0,
      '🧪 Prueba Local',
      'Las notificaciones locales funcionan',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_channel',
          'Recordatorios de Hábitos',
          importance: Importance.high,
        ),
      ),
    );
  }
}