import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_progress.dart';
import '../models/question.dart'; // 👈 Importante para leer las categorías

class DailyGoalScreen extends StatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  State<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends State<DailyGoalScreen> {
  late Box<UserProgress> _progressBox;
  UserProgress? _progress;
  final _goalController = TextEditingController();

  // Variables para la nueva funcionalidad
  String? _selectedCategory;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _progressBox = Hive.box<UserProgress>('progressBox');

    // Inicializa progreso si es la primera vez
    if (_progressBox.isEmpty) {
      _progressBox.add(UserProgress(
        dailyGoal: 3,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime(2000, 1, 1),
      ));
    }

    _progress = _progressBox.getAt(0);
    _goalController.text = _progress!.dailyGoal.toString();

    // Cargar datos existentes si los hay
    _selectedCategory = _progress?.targetCategory;
    _selectedDate = _progress?.targetDate;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveGoal() {
    final newGoal = int.tryParse(_goalController.text) ?? 3;

    // Guardamos todo: meta numérica, categoría y fecha
    _progress!
      ..dailyGoal = newGoal
      ..targetCategory = _selectedCategory
      ..targetDate = _selectedDate
      ..save();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meta y modo examen actualizados ✅'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos las categorías disponibles de la caja de preguntas
    final questionBox = Hive.box<Question>('questionsBox');
    final categories = questionBox.values
        .map((q) => q.category)
        .toSet() // Elimina duplicados
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tu meta y racha')),
      body: SingleChildScrollView( // Agregado por si la pantalla es chica
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: _progressBox.listenable(),
          builder: (context, Box<UserProgress> box, _) {
            final p = box.getAt(0)!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("🏆 Meta Diaria", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _goalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de preguntas por día',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('📅 Respondidas hoy: ${p.answeredToday}'),
                Text('🔥 Racha actual: ${p.streak} días'),

                const Divider(height: 40, thickness: 2),

                const Text("🎓 Modo Examen (Opcional)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Elige una categoría para priorizar hasta la fecha del parcial."),
                const SizedBox(height: 16),

                // Selector de Categoría
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Categoría a estudiar",
                    border: OutlineInputBorder(),
                  ),
                  value: categories.contains(_selectedCategory) ? _selectedCategory : null,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Sin filtro (Todas)")),
                    ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),

                // Selector de Fecha
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_selectedDate != null
                      ? "Fecha del parcial: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                      : "Seleccionar fecha del parcial"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Botón para limpiar filtro
                if (_selectedCategory != null || _selectedDate != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text("Limpiar Modo Examen"),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedDate = null;
                      });
                    },
                  ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveGoal,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('GUARDAR CAMBIOS'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}