import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../theme/app_colors.dart';

class DailyGoalScreen extends StatefulWidget {
  const DailyGoalScreen({super.key});

  @override
  State<DailyGoalScreen> createState() => _DailyGoalScreenState();
}

class _DailyGoalScreenState extends State<DailyGoalScreen> {
  final _goalController = TextEditingController();

  String? _selectedCategory;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final progress = context.read<ProgressRepository>().progress;
    _goalController.text = progress.dailyGoal.toString();
    _selectedCategory = progress.targetCategory;
    _selectedDate = progress.targetDate;
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  bool get _dateExpired => _selectedDate != null && DateUtils.dateOnly(_selectedDate!).isBefore(_today);

  /// El modo examen está activo con una materia elegida y sin fecha vencida.
  bool get _examActive => _selectedCategory != null && !_dateExpired;

  Future<void> _pickDate() async {
    final today = _today;
    // Si la fecha guardada ya pasó, el calendario abre en una fecha futura:
    // showDatePicker no acepta una fecha inicial anterior a firstDate.
    final selected = _selectedDate;
    final initial = selected != null && !_dateExpired ? DateUtils.dateOnly(selected) : today.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'FECHA DEL EXAMEN',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveGoal() {
    final repo = context.read<ProgressRepository>();
    final typed = int.tryParse(_goalController.text.trim());
    repo.updateGoals(
      dailyGoal: typed ?? repo.progress.dailyGoal,
      targetCategory: _selectedCategory,
      targetDate: _selectedDate,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Objetivos actualizados 🎯', style: GoogleFonts.poppins(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<QuestionRepository>().categories;

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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, size: 40, color: AppColors.amber),
                  ),
                  const SizedBox(height: 16),
                  Text("Tu Meta Diaria", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "Preguntas a responder cada día (de 1 a $kMaxDailyGoal)",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      key: const ValueKey('daily-goal'),
                      controller: _goalController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Text("Modo Examen 🎓", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              "Mientras esté activo, el quiz usa solo preguntas de esa materia. "
              "Con fecha, se desactiva solo cuando pasa el examen.",
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 12),

            // TARJETA DE MODO EXAMEN
            Container(
              key: const ValueKey('exam-card'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _examActive ? AppColors.primary : Colors.transparent, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Materia del examen",
                      labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.1),
                      prefixIcon: const Icon(Icons.category_rounded, color: AppColors.primary),
                    ),
                    dropdownColor: Theme.of(context).cardColor, // Para que el menú respete el modo oscuro
                    // initialValue solo se lee al crear el campo: la key lo recrea
                    // cuando "Desactivar Modo Examen" limpia la selección.
                    key: ValueKey(_selectedCategory),
                    initialValue: categories.contains(_selectedCategory) ? _selectedCategory : null,
                    items: [
                      DropdownMenuItem(value: null, child: Text("Sin filtro (Todas)", style: GoogleFonts.poppins())),
                      ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins())))
                    ],
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    key: const ValueKey('exam-date'),
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.teal),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Fecha del examen (opcional)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedDate != null
                                      ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}${_dateExpired ? ' · Vencido' : ''}"
                                      : "Sin fecha límite",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _dateExpired ? Colors.redAccent : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedDate != null)
                            IconButton(
                              tooltip: 'Quitar fecha',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _selectedDate = null),
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
                backgroundColor: AppColors.primary,
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
