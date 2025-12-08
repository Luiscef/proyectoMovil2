import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler para mensajes en background (debe estar fuera de la clase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Mensaje en background: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // ============ INICIALIZACIÓN ============
  Future<void> initialize() async {
    if (_initialized) return;

    // Configurar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permisos
    await _requestPermissions();

    // Obtener token FCM
    await _getToken();

    // Configurar listeners
    _setupMessageListeners();

    // Crear canal de notificaciones para Android
    await _createNotificationChannel();

    _initialized = true;
    debugPrint('✅ FCMService inicializado');
  }

  // ============ PERMISOS ============
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('📱 Permisos FCM: ${settings.authorizationStatus}');
  }

  // ============ OBTENER Y GUARDAR TOKEN ============
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }

      // Escuchar cambios de token
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 Token FCM actualizado: $newToken');
        _fcmToken = newToken;
        _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      debugPrint('❌ Error obteniendo token FCM: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No hay usuario autenticado para guardar token');
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'android', // o detectar automáticamente
      }, SetOptions(merge: true));

      debugPrint('✅ Token FCM guardado en Firestore');
    } catch (e) {
      debugPrint('❌ Error guardando token: $e');
    }
  }

  // ============ LISTENERS DE MENSAJES ============
  void _setupMessageListeners() {
    // Mensaje recibido con app en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Mensaje en foreground:');
      debugPrint('   Título: ${message.notification?.title}');
      debugPrint('   Cuerpo: ${message.notification?.body}');

      // Mostrar notificación local cuando la app está abierta
      _showLocalNotification(message);
    });

    // Usuario toca la notificación (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 Usuario abrió notificación:');
      debugPrint('   Título: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Verificar si la app se abrió desde una notificación
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App abierta desde notificación:');
      debugPrint('   Título: ${initialMessage.notification?.title}');
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Aquí puedes navegar a una pantalla específica
    final habitId = message.data['habitId'];
    if (habitId != null) {
      debugPrint('📍 Navegar a hábito: $habitId');
      // Implementar navegación
    }
  }

  // ============ MOSTRAR NOTIFICACIÓN LOCAL ============
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'Notificaciones Push',
      channelDescription: 'Notificaciones de Firebase Cloud Messaging',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['habitId'],
    );
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'fcm_channel',
      'Notificaciones Push',
      description: 'Notificaciones de Firebase Cloud Messaging',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ============ SUSCRIBIRSE A TOPICS ============
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('📢 Suscrito al topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('🔕 Desuscrito del topic: $topic');
  }

  // ============ ACTUALIZAR TOKEN DESPUÉS DE LOGIN ============
  Future<void> updateTokenAfterLogin() async {
    if (_fcmToken != null) {
      await _saveTokenToFirestore(_fcmToken!);
    } else {
      await _getToken();
    }
  }
}