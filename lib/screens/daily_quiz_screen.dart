import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

  // 🧠 ALGORITMO DE REPASO INTELIGENTE + MODO EXAMEN
  void _loadSmartQuestion() {
    if (_box.isEmpty) return;

    final progress = _progressService.progress;
    List<Question> candidates = _box.values.toList();
    String? currentModeMsg;

    // 1. Filtrado por Modo Examen (si existe meta y fecha activa)
    if (progress.targetCategory != null && progress.targetDate != null) {
      final now = DateTime.now();
      if (progress.targetDate!.isAfter(now.subtract(const Duration(days: 1)))) {
        final filtered = candidates.where((q) => q.category == progress.targetCategory).toList();
        if (filtered.isNotEmpty) {
          candidates = filtered;
          currentModeMsg = "📚 Estudiando: ${progress.targetCategory}";
        }
      }
    }

    if (candidates.isEmpty) {
      setState(() => _currentQuestion = null);
      return;
    }

    // 2. Selección Ponderada (Weighted Random)
    // Las preguntas con más errores tienen más peso (probabilidad) de salir
    final List<Question> weightedList = [];
    for (var q in candidates) {
      int weight = 1 + (q.errorCount * 2);
      if (weight > 10) weight = 10;

      for (int i = 0; i < weight; i++) {
        weightedList.add(q);
      }
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

    // 📊 Actualizamos estadísticas de la pregunta individual
    q.totalAttempts++;
    if (!isCorrect) {
      q.errorCount++; // ¡Aumenta probabilidad de aparecer mañana!
    } else {
      if (q.errorCount > 0) q.errorCount--;
    }
    q.save();

    // Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isCorrect ? '✅ ¡Correcto!' : '❌ Incorrecto'),
      backgroundColor: isCorrect ? Colors.green : Colors.red,
      duration: const Duration(milliseconds: 500),
    ));

    // 👇 CAMBIO CLAVE AQUÍ: Pasamos si acertó o no para el historial
    _progressService.incrementProgress(isCorrect);

    // 💡 MOSTRAR EXPLICACIÓN (Si existe)
    if (q.explanation != null && q.explanation!.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isCorrect ? "Muy bien 🤓" : "Ups, casi... 😅"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isCorrect ? "Así es:" : "La respuesta correcta era esa porque:"),
              const SizedBox(height: 8),
              Text(q.explanation!, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Entendido"),
            )
          ],
        ),
      );
    } else {
      // Si no hay explicación, esperamos un segundo nomás
      await Future.delayed(const Duration(seconds: 1));
    }

    _loadSmartQuestion();
  }

  @override
  Widget build(BuildContext context) {
    if (_box.isEmpty) return const Scaffold(body: Center(child: Text('No hay preguntas cargadas')));
    if (_currentQuestion == null) return const Scaffold(body: Center(child: Text("Error cargando pregunta")));

    final q = _currentQuestion!;
    final p = _progressService.progress;

    // Vista de meta completada
    if (p.answeredToday >= p.dailyGoal) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Diario')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉 ¡Meta diaria completada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                'Volvé mañana para seguir tu racha 🔥\nRacha actual: ${p.streak}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Volver al menú"))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Diario'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Text('${p.answeredToday}/${p.dailyGoal}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
        bottom: _modeMessage != null ? PreferredSize(preferredSize: const Size.fromHeight(20), child: Text(_modeMessage!, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold), textAlign: TextAlign.center)) : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (q.imagePath != null)
              Image.file(File(q.imagePath!), height: 200, fit: BoxFit.cover),
            const SizedBox(height: 16),
            Text(q.questionText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ...List.generate(q.options.length, (i) {
              final isCorrect = i == q.correctAnswerIndex;
              final isSelected = i == _selectedIndex;
              Color? color;
              if (_answered) {
                if (isCorrect) color = Colors.green.shade200;
                else if (isSelected) color = Colors.red.shade200;
              }
              return Card(
                color: color,
                child: ListTile(
                  title: Text(q.options[i]),
                  onTap: _answered ? null : () => _checkAnswer(i),
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}