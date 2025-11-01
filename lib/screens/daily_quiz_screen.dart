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

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Question>('questionsBox');
    _progressService = ProgressService();
    _loadRandomQuestion();
  }

  void _loadRandomQuestion() {
    if (_box.isEmpty) return;
    final rand = Random();
    final index = rand.nextInt(_box.length);
    setState(() {
      _currentQuestion = _box.getAt(index);
      _answered = false;
      _selectedIndex = null;
    });
  }

  void _checkAnswer(int index) {
    setState(() {
      _answered = true;
      _selectedIndex = index;
    });

    final isCorrect = index == _currentQuestion!.correctAnswerIndex;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isCorrect ? '✅ ¡Correcto!' : '❌ Incorrecto'),
      backgroundColor: isCorrect ? Colors.green : Colors.red,
    ));

    // ✅ Actualiza el progreso
    _progressService.incrementProgress();

    // Espera y carga otra pregunta
    Future.delayed(const Duration(seconds: 1), _loadRandomQuestion);
  }

  @override
  Widget build(BuildContext context) {
    if (_box.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No hay preguntas cargadas 😢')),
      );
    }

    final q = _currentQuestion!;
    final p = _progressService.progress;

    // 💡 Si alcanzó su meta diaria
    if (p.answeredToday >= p.dailyGoal) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Diario')),
        body: const Center(
          child: Text(
            '🎉 ¡Meta diaria completada!\nVolvé mañana para seguir tu racha 🔥',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              child: Text(
                '${p.answeredToday}/${p.dailyGoal}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (q.imagePath != null)
              Center(
                child: Image.file(
                  File(q.imagePath!),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              q.questionText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(q.options.length, (i) {
              final option = q.options[i];
              final isCorrect = i == q.correctAnswerIndex;
              final isSelected = i == _selectedIndex;

              Color? color;
              if (_answered) {
                if (isSelected && isCorrect) color = Colors.green;
                else if (isSelected && !isCorrect) color = Colors.red;
              }

              return Card(
                color: color,
                child: ListTile(
                  title: Text(option),
                  onTap: _answered ? null : () => _checkAnswer(i),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
