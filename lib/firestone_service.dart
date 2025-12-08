// firestone_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoneService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference get _habitsCollection {
    final uid = currentUserId;
    if (uid == null) throw Exception('Usuario no autenticado');
    return _db.collection('users').doc(uid).collection('habits');
  }

  // Obtener stream de hábitos (ordenados)
  Stream<QuerySnapshot> getHabitsStream() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();
    return _habitsCollection.orderBy('createdAt', descending: true).snapshots();
  }

  // Obtener stream de un hábito específico
  Stream<DocumentSnapshot> getHabitStream(String habitId) {
    return _habitsCollection.doc(habitId).snapshots();
  }

  // Añadir hábito: ahora acepta reminderTime (TimeOfDay?) y guarda campos base
  Future<DocumentReference?> addHabito(
    String name,
    String description,
    String frequency, {
    TimeOfDay? reminderTime,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    final Map<String, dynamic> payload = {
      'name': name,
      'description': description,
      'frequency': frequency,
      'completed': false,
      'progress': 0,
      'streak': 0,
      'bestStreak': 0,
      'completionHistory': <String>[], // guardamos fechas 'YYYY-MM-DD'
      'createdAt': FieldValue.serverTimestamp(),
      'lastCompleted': null,
    };

    if (reminderTime != null) {
      payload['reminderHour'] = reminderTime.hour;
      payload['reminderMinute'] = reminderTime.minute;
    } else {
      payload['reminderHour'] = null;
      payload['reminderMinute'] = null;
    }

    return await _habitsCollection.add(payload);
  }

  // Actualizar hábito (ahora opcional reminderTime)
  Future<void> updateHabito(
    String id,
    String name,
    String description,
    String frequency, {
    TimeOfDay? reminderTime,
  }) async {
    final Map<String, dynamic> updateData = {
      'name': name,
      'description': description,
      'frequency': frequency,
    };

    if (reminderTime != null) {
      updateData['reminderHour'] = reminderTime.hour;
      updateData['reminderMinute'] = reminderTime.minute;
    } else {
      // si quieres eliminar el recordatorio cuando no hay reminderTime:
      updateData['reminderHour'] = FieldValue.delete();
      updateData['reminderMinute'] = FieldValue.delete();
    }

    await _habitsCollection.doc(id).update(updateData);
  }

  // Eliminar hábito
  Future<void> deleteHabit(String id) async {
    await _habitsCollection.doc(id).delete();
  }

  // Helper: formatea DateTime a 'YYYY-MM-DD'
  String _formatDateStr(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // Comprueba si una fecha aparece en completionHistory (acepta List<dynamic>)
  bool isCompletedForDate(List<dynamic> history, DateTime date) {
    try {
      final dateStr = _formatDateStr(date);
      return history.map((e) => e.toString()).contains(dateStr);
    } catch (_) {
      return false;
    }
  }

  // Nueva función: marcar/desmarcar completado para UNA FECHA específica
  Future<void> toggleHabitCompletedForDate(
    String id,
    bool completed,
    DateTime date,
  ) async {
    final docRef = _habitsCollection.doc(id);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};

    String target = _formatDateStr(date);

    List<String> history = List<String>.from(data['completionHistory'] ?? <dynamic>[]);
    int progress = (data['progress'] ?? 0) as int;
    int streak = (data['streak'] ?? 0) as int;
    int bestStreak = (data['bestStreak'] ?? 0) as int;

    if (completed) {
      if (!history.contains(target)) {
        history.add(target);
        progress++;

        // recalcular racha: la lógica simple es comprobar días consecutivos hacia atrás
        // calculamos racha basada en presence of yesterday, yesterday-1, ...
        int newStreak = 1;
        DateTime cursor = date.subtract(const Duration(days: 1));
        while (history.contains(_formatDateStr(cursor))) {
          newStreak++;
          cursor = cursor.subtract(const Duration(days: 1));
        }
        streak = newStreak;
        if (streak > bestStreak) bestStreak = streak;
      }
    } else {
      if (history.contains(target)) {
        history.remove(target);
        progress = progress > 0 ? progress - 1 : 0;

        // si removemos la fecha, recalculamos la racha actual (desde la fecha más reciente)
        // buscar la fecha más reciente en history
        if (history.isEmpty) {
          streak = 0;
        } else {
          // convertir a DateTime y ordenar desc
          final dates = history.map((s) {
            try {
              final parts = s.split('-').map(int.parse).toList();
              return DateTime(parts[0], parts[1], parts[2]);
            } catch (_) {
              return DateTime(1970);
            }
          }).where((d) => d.year > 1970).toList();

          dates.sort((a, b) => b.compareTo(a)); // desc
          // calcular racha desde dates.first (más reciente) hacia atrás
          DateTime cursor = dates.first;
          int currentRacha = 1;
          DateTime prev = cursor.subtract(const Duration(days: 1));
          while (dates.contains(prev)) {
            currentRacha++;
            prev = prev.subtract(const Duration(days: 1));
          }
          streak = currentRacha;
        }
      }
    }

    await docRef.update({
      'completed': completed,
      'lastCompleted': completed ? FieldValue.serverTimestamp() : null,
      'completionHistory': history,
      'progress': progress,
      'streak': streak,
      'bestStreak': bestStreak,
    });
  }

  // Compatibilidad: versión simple sin fecha (marca hoy)
  Future<void> toggleHabitCompleted(String id, bool completed) async {
    await toggleHabitCompletedForDate(id, completed, DateTime.now());
  }

  // Actualizar progreso explícito
  Future<void> updateProgreso(String id, int progress) async {
    await _habitsCollection.doc(id).update({
      'progress': progress,
    });
  }

  // Reset diario (por si lo usas)
  Future<void> resetDailyHabits() async {
    final snapshot = await _habitsCollection.get();
    final batch = _db.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'completed': false});
    }

    await batch.commit();
  }
}
