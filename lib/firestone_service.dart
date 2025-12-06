import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoneService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Crear Hábito
  Future<void> addHabito(String name, String description, String frequency) async {
    await _db.collection('habitos').add({
      'name': name,
      'description': description,
      'frequency': frequency, // si es diaria, semanal o mensual
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastCompleted': null,
    });
  }

  // Leer Hábitos
  Stream<QuerySnapshot> getHabitsStream() {
    return _db.collection('habitos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Actualizar Hábito
  Future<void> updateHabito(
    String id,
    String name,
    String description,
    String frequency,
  ) async {
    await _db.collection('habitos').doc(id).update({
      'name': name,
      'description': description,
      'frequency': frequency,
    });
  }

  Future<void> toggleHabitCompleted(String id, bool completed) async {
    await _db.collection('habitos').doc(id).update({
      'completed': completed,
      'lastCompleted': completed ? FieldValue.serverTimestamp() : null,
    });
  }

  // Eliminar Hábito
  Future<void> deleteHabit(String id) async {
    await _db.collection('habitos').doc(id).delete();
  }


Future<void> updateProgreso(String id, int progreso) async {
  await _db.collection('habitos').doc(id).update({'progreso': progreso});
}
}