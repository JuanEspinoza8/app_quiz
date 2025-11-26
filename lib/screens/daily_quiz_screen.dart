import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../services/progress_service.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  late final Box<Question> _box;
  late final ProgressService _progressService;
  Question? _currentQuestion;
  bool _answered = false;
  int? _selectedIndex;
  String? _modeMessage;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Question>('questionsBox');
    _progressService = ProgressService();
    _loadSmartQuestion();
  }

  void _loadSmartQuestion() {
    if (_box.isEmpty) return;

    final progress = _progressService.progress;
    // 👇 1. Obtenemos todas las preguntas
    List<Question> candidates = _box.values.toList();
    String? currentModeMsg;

    // 👇 2. FILTRO NUEVO: Quitamos las categorías desactivadas
    if (progress.hiddenCategories.isNotEmpty) {
      candidates = candidates.where((q) => !progress.hiddenCategories.contains(q.category)).toList();
    }

    // Lógica de Modo Examen
    if (progress.targetCategory != null && progress.targetDate != null) {
      final now = DateTime.now();
      if (progress.targetDate!.isAfter(now.subtract(const Duration(days: 1)))) {
        final filtered = candidates.where((q) => q.category == progress.targetCategory).toList();
        if (filtered.isNotEmpty) {
          candidates = filtered;
          currentModeMsg = "📚 Modo Examen: ${progress.targetCategory}";
        }
      }
    }

    // Si después de filtrar no queda nada
    if (candidates.isEmpty) {
      setState(() {
        _currentQuestion = null;
        _modeMessage = "¡No hay preguntas habilitadas!";
      });
      return;
    }

    // Selección Ponderada
    final List<Question> weightedList = [];
    for (var q in candidates) {
      int weight = 1 + (q.errorCount * 2);
      if (weight > 10) weight = 10;
      for (int i = 0; i < weight; i++) weightedList.add(q);
    }

    final rand = Random();
    final index = rand.nextInt(weightedList.length);

    setState(() {
      _currentQuestion = weightedList[index];
      _answered = false;
      _selectedIndex = null;
      _modeMessage = currentModeMsg;
    });
  }

  void _checkAnswer(int index) async {
    setState(() {
      _answered = true;
      _selectedIndex = index;
    });

    final isCorrect = index == _currentQuestion!.correctAnswerIndex;
    final q = _currentQuestion!;

    if (isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }

    q.totalAttempts++;
    if (!isCorrect) {
      q.errorCount++;
    } else {
      if (q.errorCount > 0) q.errorCount--;
    }
    q.save();

    _progressService.incrementProgress(isCorrect);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isCorrect ? '✨ ¡Correcto! Sigue así' : '❌ Incorrecto, repasaremos esto'),
      backgroundColor: isCorrect ? const Color(0xFF4ECDC4) : const Color(0xFFFF6584),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(milliseconds: 800),
    ));

    if (q.explanation != null && q.explanation!.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isCorrect ? "¡Bien hecho!" : "Ojo al dato 💡"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isCorrect ? "Sabías que..." : "La correcta era esa porque:"),
              const SizedBox(height: 8),
              Text(q.explanation!, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Continuar", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    } else {
      await Future.delayed(const Duration(seconds: 1));
    }

    _loadSmartQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (_box.isEmpty) return const Scaffold(body: Center(child: Text('Agrega preguntas para empezar ✍️')));
    if (_currentQuestion == null) return const Scaffold(body: Center(child: Text("¡No hay preguntas disponibles!")));

    final q = _currentQuestion!;
    final p = _progressService.progress;

    if (p.answeredToday >= p.dailyGoal) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                Text('¡Meta diaria cumplida!', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text('Racha actual: ${p.streak} días 🔥', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Volver al Inicio"),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeMessage ?? "Quiz Diario", style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // ✅ Dinámico
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Text('${p.answeredToday}/${p.dailyGoal}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          )
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: p.answeredToday / p.dailyGoal,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1), // ✅ Más sutil
            color: const Color(0xFF4ECDC4),
            minHeight: 6,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de la Pregunta
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, // ✅ Dinámico
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        if (q.imagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(File(q.imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover),
                          ),
                        if (q.imagePath != null) const SizedBox(height: 20),
                        Text(
                          q.questionText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            // ✅ Quitamos color fijo
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), // ✅ Fondo más genérico
                          child: Text(q.category, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Opciones de Respuesta
                  ...List.generate(q.options.length, (i) {
                    final isCorrect = i == q.correctAnswerIndex;
                    final isSelected = i == _selectedIndex;

                    Color bgColor = Theme.of(context).cardColor; // ✅ Base dinámica
                    Color borderColor = Colors.transparent;
                    Color? textColor; // Dejar null para que use el tema por defecto

                    if (_answered) {
                      if (isCorrect) {
                        bgColor = const Color(0xFF4ECDC4).withOpacity(0.2);
                        borderColor = const Color(0xFF4ECDC4);
                        textColor = const Color(0xFF1A535C);
                        if (Theme.of(context).brightness == Brightness.dark) textColor = const Color(0xFF4ECDC4); // Ajuste para dark mode
                      } else if (isSelected) {
                        bgColor = const Color(0xFFFF6584).withOpacity(0.2);
                        borderColor = const Color(0xFFFF6584);
                        textColor = const Color(0xFFA3001B);
                        if (Theme.of(context).brightness == Brightness.dark) textColor = const Color(0xFFFF6584); // Ajuste para dark mode
                      } else {
                        bgColor = Theme.of(context).cardColor.withOpacity(0.5); // Deshabilitado visualmente
                        textColor = Colors.grey;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _answered ? null : () => _checkAnswer(i),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _answered ? borderColor : Colors.transparent, width: 2),
                            boxShadow: [
                              if (!_answered) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: _answered && isCorrect ? const Color(0xFF4ECDC4) : Colors.grey.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + i), // A, B, C, D
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _answered && isCorrect ? Colors.white : Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  q.options[i],
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                                ),
                              ),
                              if (_answered && isCorrect) const Icon(Icons.check_circle, color: Color(0xFF4ECDC4)),
                              if (_answered && isSelected && !isCorrect) const Icon(Icons.cancel, color: Color(0xFFFF6584)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}