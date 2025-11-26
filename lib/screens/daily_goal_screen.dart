import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_progress.dart';
import '../models/question.dart';

class DailyGoalScreen extends StatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  State<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends State<DailyGoalScreen> {
  late Box<UserProgress> _progressBox;
  UserProgress? _progress;
  final _goalController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _progressBox = Hive.box<UserProgress>('progressBox');

    if (_progressBox.isEmpty) {
      _progressBox.add(UserProgress(
          dailyGoal: 3,
          answeredToday: 0,
          streak: 0,
          lastPlayedDate: DateTime(2000, 1, 1)
      ));
    }

    _progress = _progressBox.getAt(0);
    _goalController.text = _progress!.dailyGoal.toString();
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
      builder: (context, child) {
        // Aseguramos que el DatePicker use el tema correcto o forzamos uno compatible
        return Theme(
          data: Theme.of(context).brightness == Brightness.dark
              ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6C63FF)))
              : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF6C63FF))),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveGoal() {
    final newGoal = int.tryParse(_goalController.text) ?? 3;
    _progress!
      ..dailyGoal = newGoal
      ..targetCategory = _selectedCategory
      ..targetDate = _selectedDate
      ..save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Objetivos actualizados 🎯', style: GoogleFonts.poppins(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final questionBox = Hive.box<Question>('questionsBox');
    final categories = questionBox.values.map((q) => q.category).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Metas y Estudio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TARJETA DE META DIARIA
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // ✅ Dinámico
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFBC42).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, size: 40, color: Color(0xFFFFBC42)),
                  ),
                  const SizedBox(height: 16),
                  Text("Tu Meta Diaria", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Preguntas a responder cada día", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1), // ✅ Neutro
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: TextField(
                          controller: _goalController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF)),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Text("Modo Examen 🎓", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 12),

            // TARJETA DE MODO EXAMEN
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // ✅ Dinámico
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: (_selectedCategory != null) ? const Color(0xFF6C63FF) : Colors.transparent,
                    width: 2
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Materia a priorizar",
                      labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1), // ✅ Neutro
                      prefixIcon: const Icon(Icons.category_rounded, color: Color(0xFF6C63FF)),
                    ),
                    dropdownColor: Theme.of(context).cardColor, // ✅ Para que el menú no sea blanco
                    value: categories.contains(_selectedCategory) ? _selectedCategory : null,
                    items: [
                      DropdownMenuItem(value: null, child: Text("Sin filtro (Todas)", style: GoogleFonts.poppins())),
                      ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins())))
                    ],
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1), // ✅ Neutro
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: Color(0xFF4ECDC4)),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Fecha del parcial", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _selectedDate != null
                                    ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}"
                                    : "Seleccionar fecha",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_selectedCategory != null || _selectedDate != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton.icon(
                          onPressed: () => setState(() { _selectedCategory = null; _selectedDate = null; }),
                          icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: Colors.redAccent),
                          label: Text("Desactivar Modo Examen", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ),
                    )
                ],
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text("Guardar Cambios", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}