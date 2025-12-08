import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestone_service.dart';

class HabitProgressPage extends StatelessWidget {
  final String habitId;
  final Map<String, dynamic> habitData;

  const HabitProgressPage({
    super.key,
    required this.habitId,
    required this.habitData,
  });

  @override
  Widget build(BuildContext context) {
    final service = FirestoneService();

    return Scaffold(
      appBar: AppBar(
        title: Text(habitData['name'] ?? 'Progreso'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: service.getHabitStream(habitId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final progress = data['progress'] ?? 0;
          final streak = data['streak'] ?? 0;
          final bestStreak = data['bestStreak'] ?? 0;
          final history = List<dynamic>.from(data['completionHistory'] ?? []);
          final createdAt = data['createdAt'] as Timestamp?;

          int totalDays = 1;
          if (createdAt != null) {
            totalDays = DateTime.now().difference(createdAt.toDate()).inDays + 1;
          }

          double completionRate = totalDays > 0 ? (progress / totalDays * 100) : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta principal de progreso
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: CircularProgressIndicator(
                                value: completionRate / 100,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  completionRate >= 80
                                      ? Colors.green
                                      : completionRate >= 50
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${completionRate.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Cumplimiento'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Estadísticas
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Días Cumplidos',
                        '$progress',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Racha Actual',
                        '$streak días',
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Mejor Racha',
                        '$bestStreak días',
                        Icons.emoji_events,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Días Totales',
                        '$totalDays',
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Calendario de los últimos 30 días
                Text(
                  'Últimos 30 días',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildCalendarGrid(history),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<dynamic> history) {
    final today = DateTime.now();
    final days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isCompleted = history.contains(dateStr);
        final isToday = _isSameDay(date, today);

        return Container(
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
            border: isToday ? Border.all(color: Colors.teal, width: 2) : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                color: isCompleted ? Colors.white : Colors.black54,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}