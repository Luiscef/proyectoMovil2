import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_config.dart';

const String kCheckHabitsTask = 'checkHabitsTask';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(options: firebaseConfig);

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await flutterLocalNotificationsPlugin.initialize(initSettings);


      final snapshot = await FirebaseFirestore.instance.collection('habits').get();

      int idCounter = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completed = data['completed'] ?? false;
        final name = data['name'] ?? 'Hábito';
        if (!completed) {
          const androidDetails = AndroidNotificationDetails(
            'habits_channel',
            'Recordatorio de Hábitos',
            channelDescription: 'Notificaciones para recordar completar hábitos',
            importance: Importance.max,
            priority: Priority.high,
          );
          const platformDetails = NotificationDetails(android: androidDetails);

          await flutterLocalNotificationsPlugin.show(
            idCounter++,
            'Recordatorio: $name',
            'No olvides completar tu hábito de hoy',
            platformDetails,
          );
        }
      }

      print('Notificaciones enviadas correctamente');
      return Future.value(true);
    } catch (e) {
      print('Error en callbackDispatcher: $e');
      return Future.value(false);
    }
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'habits_channel',
      'Recordatorio de Hábitos',
      channelDescription: 'Notificaciones para recordar completar hábitos',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
  }

  Future<void> initializeWorkManager({bool forDebugRegisterOneOff = false}) async {

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerPeriodicTask(
      'habits_reminder',
      kCheckHabitsTask,
      frequency: const Duration(minutes: 1),
    );

    if (forDebugRegisterOneOff) {
      await Workmanager().registerOneOffTask('habits_test_once', kCheckHabitsTask);
      print('Tarea one-off registrada para pruebas');
    }
  }
}