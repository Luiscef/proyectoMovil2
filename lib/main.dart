import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_config.dart';
import 'firestone_service.dart';
import 'register.dart';
import 'profile.dart';
import 'habit_progress_page.dart';
import 'habit_history_page.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  
  // Cargar preferencias del tema
  final themeProvider = ThemeProvider();
  await themeProvider.loadPreferences();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Mis Hábitos',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HabitsPage();
        }

        return const RegisterPage();
      },
    );
  }
}

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final FirestoneService _service = FirestoneService();
  int _selectedTab = 0;
  DateTime _selectedDate = DateTime.now();

  Future<void> _addHabit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddHabitDialog(),
    );

    if (result != null) {
      await _service.addHabito(
        result['name'] ?? '',
        result['description'] ?? '',
        result['frequency'] ?? 'daily',
        reminderTime: result['reminderTime'],
      );
    }
  }

  Future<void> _editHabit(String id, Map<String, dynamic> habitData) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditHabitDialog(habit: habitData),
    );

    if (result != null) {
      await _service.updateHabito(
        id,
        result['name'] ?? '',
        result['description'] ?? '',
        result['frequency'] ?? 'daily',
        reminderTime: result['reminderTime'],
      );
    }
  }

  Future<void> _deleteHabit(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Hábito'),
        content: const Text('¿Estás seguro de eliminar este hábito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await _service.deleteHabit(id);
    }
  }

  void _viewProgress(String habitId, Map<String, dynamic> habitData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitProgressPage(habitId: habitId, habitData: habitData),
      ),
    );
  }

  void _viewHistory(String habitId, Map<String, dynamic> habitData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitHistoryPage(habitId: habitId, habitData: habitData),
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return '';
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Hábitos'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: _addHabit,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Estadísticas'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return _buildHabitsTab();
      case 1:
        return const StatsPage();
      case 2:
        return const ProfilePage();
      default:
        return _buildHabitsTab();
    }
  }

  Widget _buildHabitsTab() {
    return Column(
      children: [
        _buildCalendar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.getHabitsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final habits = snapshot.data!.docs;
              if (habits.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Sin hábitos aún',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('¡Crea tu primer hábito!'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: habits.length,
                itemBuilder: (context, i) {
                  final doc = habits[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildHabitCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(_selectedDate),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = _selectedDate.subtract(Duration(days: 7 - index));
                final isSelected = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal
                          : (isToday ? Colors.teal[100] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: Colors.teal, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayName(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(String id, Map<String, dynamic> data) {
    final name = data['name'] ?? '';
    final description = data['description'] ?? '';
    final frequency = data['frequency'] ?? 'daily';
    final lastCompleted = data['lastCompleted'];
    final progress = data['progress'] ?? 0;
    final streak = data['streak'] ?? 0;
    final history = List<dynamic>.from(data['completionHistory'] ?? []);

    final isCompletedForSelectedDate = _service.isCompletedForDate(history, _selectedDate);

    return GestureDetector(
      onTap: () => _viewProgress(id, data),
      onLongPress: () => _editHabit(id, data),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                isCompletedForSelectedDate ? Colors.teal[100]! : Colors.orange[50]!,
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isCompletedForSelectedDate,
                    onChanged: (v) async {
                      await _service.toggleHabitCompletedForDate(
                        id,
                        v ?? false,
                        _selectedDate,
                      );
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: isCompletedForSelectedDate
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isCompletedForSelectedDate ? Colors.grey : Colors.black,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editHabit(id, data);
                          break;
                        case 'progress':
                          _viewProgress(id, data);
                          break;
                        case 'history':
                          _viewHistory(id, data);
                          break;
                        case 'delete':
                          _deleteHabit(id);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'progress', child: Text('Ver Progreso')),
                      const PopupMenuItem(value: 'history', child: Text('Ver Historial')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(Icons.local_fire_department, '$streak días', Colors.orange),
                  _buildStatChip(Icons.check_circle, '$progress total', Colors.green),
                  Text(
                    _getFrequencyLabel(frequency),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getDayName(DateTime date) {
    const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return days[date.weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return months[month - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getFrequencyLabel(String freq) {
    switch (freq) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensual';
      default:
        return freq;
    }
  }
}

// Diálogo para agregar hábito
class AddHabitDialog extends StatefulWidget {
  const AddHabitDialog({super.key});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  String selectedFrequency = 'daily';
  TimeOfDay? reminderTime;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear Hábito'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Hábito',
                hintText: 'Ej. Hacer ejercicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej. 30 minutos de cardio',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Diario')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
              ],
              onChanged: (v) => setState(() => selectedFrequency = v ?? 'daily'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications),
              title: Text(
                reminderTime != null
                    ? 'Recordatorio: ${reminderTime!.format(context)}'
                    : 'Agregar recordatorio',
              ),
              trailing: reminderTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => reminderTime = null),
                    )
                  : null,
              onTap: _selectTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('El nombre es requerido')),
              );
              return;
            }
            Navigator.pop(context, {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'frequency': selectedFrequency,
              'reminderTime': reminderTime,
            });
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

// Diálogo para editar hábito
class EditHabitDialog extends StatefulWidget {
  final Map<String, dynamic> habit;
  const EditHabitDialog({super.key, required this.habit});

  @override
  State<EditHabitDialog> createState() => _EditHabitDialogState();
}

class _EditHabitDialogState extends State<EditHabitDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  late String selectedFrequency;
  TimeOfDay? reminderTime;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.habit['name']);
    descCtrl = TextEditingController(text: widget.habit['description']);
    selectedFrequency = widget.habit['frequency'] ?? 'daily';

    final hour = widget.habit['reminderHour'];
    final minute = widget.habit['reminderMinute'];
    if (hour != null && minute != null) {
      reminderTime = TimeOfDay(hour: hour, minute: minute);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Hábito'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Hábito',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Diario')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
              ],
              onChanged: (v) => setState(() => selectedFrequency = v ?? 'daily'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications),
              title: Text(
                reminderTime != null
                    ? 'Recordatorio: ${reminderTime!.format(context)}'
                    : 'Agregar recordatorio',
              ),
              trailing: reminderTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => reminderTime = null),
                    )
                  : null,
              onTap: _selectTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'frequency': selectedFrequency,
              'reminderTime': reminderTime,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Página de estadísticas
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoneService();

    return StreamBuilder<QuerySnapshot>(
      stream: service.getHabitsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final habits = snapshot.data!.docs;
        int totalHabits = habits.length;
        int totalCompleted = 0;
        int totalStreak = 0;
        int bestStreak = 0;

        for (var doc in habits) {
          final data = doc.data() as Map<String, dynamic>;
          totalCompleted += (data['progress'] ?? 0) as int;
          totalStreak += (data['streak'] ?? 0) as int;
          final habitBest = (data['bestStreak'] ?? 0) as int;
          if (habitBest > bestStreak) bestStreak = habitBest;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen General',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Hábitos Activos',
                      '$totalHabits',
                      Icons.favorite,
                      Colors.pink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Total Completados',
                      '$totalCompleted',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Racha Actual',
                      '$totalStreak días',
                      Icons.local_fire_department,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Mejor Racha',
                      '$bestStreak días',
                      Icons.emoji_events,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Progreso por Hábito',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...habits.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? '';
                final progress = data['progress'] ?? 0;
                final streak = data['streak'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text('Completados: $progress | Racha: $streak días'),
                    trailing: CircleAvatar(
                      backgroundColor: Colors.teal[100],
                      child: Text('$progress'),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}