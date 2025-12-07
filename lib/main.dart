import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_config.dart';
import 'firestone_service.dart';
import 'register.dart';
import 'profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Hábitos',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const AuthGate(),
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddHabitDialog(),
    );

    if (result != null) {
      await _service.addHabito(
        result['name'] ?? '',
        result['description'] ?? '',
        result['frequency'] ?? 'daily',
      );
    }
  }

  Future<void> _editHabit(String id, Map<String, dynamic> habitData) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => EditHabitDialog(habit: habitData),
    );

    if (result != null) {
      await _service.updateHabito(
        id,
        result['name'] ?? '',
        result['description'] ?? '',
        result['frequency'] ?? 'daily',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await _service.deleteHabit(id);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Hábitos'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _selectedTab == 0
          ? Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _service.getHabitsStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 64);
                    final docs = snapshot.data!.docs;
                    final total = docs.length;
                    final completed = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['completed'] == true;
                    }).length;
                    final percent = total == 0
                        ? 0
                        : ((completed / total) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Tareas: $total',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            label: Text('Completadas: $completed'),
                            backgroundColor: Colors.green[50],
                          ),
                          const Spacer(),
                          Text(
                            '$percent%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildCalendar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _service.getHabitsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final habits = snapshot.data!.docs;
                      if (habits.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sin hábitos aún',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
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
                          final name = data['name'] ?? '';
                          final description = data['description'] ?? '';
                          final frequency = data['frequency'] ?? 'daily';
                          final completed = data['completed'] ?? false;
                          final lastCompleted = data['lastCompleted'];
                          final progress = data['progress'] ?? 0;

                          return _buildHabitCard(
                            doc.id,
                            name,
                            description,
                            frequency,
                            completed,
                            lastCompleted,
                            progress,
                            data,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            )
          : (_selectedTab == 1 ? const StatsPage() : const LogoRotate()),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
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

                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildHabitCard(
    String id,
    String name,
    String description,
    String frequency,
    bool completed,
    dynamic lastCompleted,
    int progress,
    Map<String, dynamic> data,
  ) {
    return GestureDetector(
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
                completed ? Colors.teal[100]! : Colors.orange[50]!,
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
                    value: completed,
                    onChanged: (v) async {
                      await _service.toggleHabitCompleted(id, v ?? false);
                      if (!mounted) return;
                      if (v ?? false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tarea completada')),
                        );
                      }
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
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: completed ? Colors.grey : Colors.black,
                          ),
                        ),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Editar Hábito',
                    onPressed: () => _editHabit(id, data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Eliminar Hábito',
                    onPressed: () => _deleteHabit(id),
                  ),
                ],
              ),

              // Mostrar etiqueta solo si está completado
              if (completed)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    label: const Text(
                      'Tarea completada',
                      style: TextStyle(color: Colors.green),
                    ),
                    backgroundColor: Colors.green[50],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.red[100],
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red),
                          onPressed: () {
                            if (progress > 0) {
                              _service.updateProgreso(id, progress - 1);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            _service.updateProgreso(id, progress + 1);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getDayName(DateTime date) {
    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    return days[date.weekday % 7];
  }

  String _getMonthName(int month) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
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

class AddHabitDialog extends StatefulWidget {
  const AddHabitDialog({super.key});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  String selectedFrequency = 'daily';

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
              onChanged: (v) =>
                  setState(() => selectedFrequency = v ?? 'daily'),
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
            });
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.habit['name']);
    descCtrl = TextEditingController(text: widget.habit['description']);
    selectedFrequency = widget.habit['frequency'] ?? 'daily';
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
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
              onChanged: (v) =>
                  setState(() => selectedFrequency = v ?? 'daily'),
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
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.show_chart, size: 72, color: Colors.teal),
            SizedBox(height: 12),
            Text(
              'Mari ponga las estadisticas jajajaja',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
