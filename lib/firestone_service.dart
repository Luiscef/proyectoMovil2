import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FirestoneService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference get _habitsCollection {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');
    return _db.collection('users').doc(uid).collection('habits');
  }

  Stream<QuerySnapshot> getHabitsStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();
    return _habitsCollection.orderBy('createdAt', descending: true).snapshots();
  }

  // ============ AGREGAR HÁBITO ============
  Future<DocumentReference?> addHabito(
    String name,
    String description,
    String frequency, {
    TimeOfDay? reminderTime,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    final docRef = await _habitsCollection.add({
      'name': name,
      'description': description,
      'frequency': frequency,
      'completed': false,
      'progress': 0,
      'streak': 0,
      'bestStreak': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastCompleted': null,
      'completionHistory': <String>[],
      'reminderHour': reminderTime?.hour,
      'reminderMinute': reminderTime?.minute,
    });

    // PROGRAMAR NOTIFICACIÓN SI HAY RECORDATORIO
    if (reminderTime != null) {
      debugPrint('📅 Programando recordatorio para: $name');
      await _notificationService.scheduleHabitReminder(
        habitId: docRef.id,
        habitName: name,
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        frequency: frequency,
      );
    }

    return docRef;
  }

  // ============ ACTUALIZAR HÁBITO ============
  Future<void> updateHabito(
    String id,
    String name,
    String description,
    String frequency, {
    TimeOfDay? reminderTime,
  }) async {
    await _habitsCollection.doc(id).update({
      'name': name,
      'description': description,
      'frequency': frequency,
      'reminderHour': reminderTime?.hour,
      'reminderMinute': reminderTime?.minute,
    });

    // ACTUALIZAR O CANCELAR NOTIFICACIÓN
    if (reminderTime != null) {
      debugPrint('📅 Actualizando recordatorio para: $name');
      await _notificationService.scheduleHabitReminder(
        habitId: id,
        habitName: name,
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        frequency: frequency,
      );
    } else {
      debugPrint('🗑️ Cancelando recordatorio para: $name');
      await _notificationService.cancelHabitReminder(id);
    }
  }

  // ============ ELIMINAR HÁBITO ============
  Future<void> deleteHabit(String id) async {
    // Cancelar notificación antes de eliminar
    await _notificationService.cancelHabitReminder(id);
    await _habitsCollection.doc(id).delete();
  }

  // ============ TOGGLE COMPLETADO ============
  Future<void> toggleHabitCompletedForDate(String id, bool completed, DateTime date) async {
    final doc = _habitsCollection.doc(id);
    final snapshot = await doc.get();

    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    int currentProgress = (data['progress'] ?? 0) as int;
    int currentStreak = (data['streak'] ?? 0) as int;
    int bestStreak = (data['bestStreak'] ?? 0) as int;
    List<String> history = List<String>.from(data['completionHistory'] ?? []);

    final dateStr = _formatDateString(date);

    if (completed) {
      if (!history.contains(dateStr)) {
        history.add(dateStr);
        currentProgress++;
        currentStreak = _calculateStreak(history);
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      }
    } else {
      if (history.contains(dateStr)) {
        history.remove(dateStr);
        currentProgress = currentProgress > 0 ? currentProgress - 1 : 0;
        currentStreak = _calculateStreak(history);
      }
    }

    await doc.update({
      'completed': _isCompletedToday(history),
      'progress': currentProgress,
      'streak': currentStreak,
      'bestStreak': bestStreak,
      'lastCompleted': completed ? FieldValue.serverTimestamp() : data['lastCompleted'],
      'completionHistory': history,
    });
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateStreak(List<String> history) {
    if (history.isEmpty) return 0;

    List<DateTime> dates = history.map((d) {
      final parts = d.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList();

    dates.sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    for (var date in dates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final diff = checkDate.difference(normalizedDate).inDays;

      if (diff == 0 || diff == 1) {
        streak++;
        checkDate = normalizedDate;
      } else {
        break;
      }
    }

    return streak;
  }

  bool _isCompletedToday(List<String> history) {
    final today = DateTime.now();
    final todayStr = _formatDateString(today);
    return history.contains(todayStr);
  }

  bool isCompletedForDate(List<dynamic> history, DateTime date) {
    final dateStr = _formatDateString(date);
    return history.map((e) => e.toString()).contains(dateStr);
  }

  Future<void> updateProgreso(String id, int progress) async {
    await _habitsCollection.doc(id).update({
      'progress': progress,
    });
  }

  Future<void> toggleHabitCompleted(String id, bool completed) async {
    await toggleHabitCompletedForDate(id, completed, DateTime.now());
  }

  Stream<DocumentSnapshot> getHabitStream(String id) {
    return _habitsCollection.doc(id).snapshots();
  }
}