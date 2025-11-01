import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_progress.dart';

class DailyGoalScreen extends StatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  State<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends State<DailyGoalScreen> {
  late Box<UserProgress> _box;
  UserProgress? _progress;
  final _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _box = Hive.box<UserProgress>('progressBox');

    // 🟣 Inicializa progreso si es la primera vez
    if (_box.isEmpty) {
      _box.add(UserProgress(
        dailyGoal: 3,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime(2000, 1, 1), // 👈 así detectamos primer inicio
      ));
    }

    _progress = _box.getAt(0);
    _goalController.text = _progress!.dailyGoal.toString();
  }

  void _saveGoal() {
    final newGoal = int.tryParse(_goalController.text) ?? 3;
    _progress!
      ..dailyGoal = newGoal
      ..save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meta actualizada a $newGoal preguntas por día ✅'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu meta y racha')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: _box.listenable(),
          builder: (context, Box<UserProgress> box, _) {
            final p = box.getAt(0)!;

            return Column(
              children: [
                TextField(
                  controller: _goalController,
                  keyboardType: TextInputType.number,
                  decoration:
                  const InputDecoration(labelText: 'Meta diaria (preguntas)'),
                ),
                const SizedBox(height: 16),
                Text('📅 Preguntas respondidas hoy: ${p.answeredToday}'),
                Text('🔥 Racha actual: ${p.streak} días'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveGoal,
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
