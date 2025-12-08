import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestone_service.dart';

class HabitHistoryPage extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> habitData;

  const HabitHistoryPage({
    super.key,
    required this.habitId,
    required this.habitData,
  });

  @override
  Widget build(BuildContext context) {
    final service = FirestoneService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial: ${habitData['name'] ?? ''}'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: service.getHabitStream(habitId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final history = List<String>.from(data['completionHistory'] ?? []);
          final createdAt = data['createdAt'] as Timestamp?;

          // Generar lista de todos los días desde la creación
          List<DateTime> allDays = [];
          if (createdAt != null) {
            DateTime startDate = createdAt.toDate();
            DateTime today = DateTime.now();
            for (var d = startDate; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
              allDays.add(DateTime(d.year, d.month, d.day));
            }
          }

          allDays = allDays.reversed.toList(); // Más recientes primero

          if (allDays.isEmpty) {
            return const Center(
              child: Text('No hay historial disponible'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allDays.length,
            itemBuilder: (context, index) {
              final date = allDays[index];
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final isCompleted = history.contains(dateStr);
              final isToday = _isSameDay(date, DateTime.now());

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isCompleted ? Colors.green[50] : Colors.red[50],
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? Colors.green : Colors.red[300],
                    child: Icon(
                      isCompleted ? Icons.check : Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    isCompleted ? 'Completado ✓' : 'No completado',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.red,
                    ),
                  ),
                  trailing: isToday
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'HOY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

    return '${days[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]} ${date.year}';
  }
}