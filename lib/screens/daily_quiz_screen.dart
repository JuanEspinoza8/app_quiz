import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../theme/app_colors.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../widgets/question_image.dart';

class DailyQuizScreen extends StatefulWidget {
  /// Fuente de azar para elegir y mezclar; los tests la fijan.
  final Random? random;

  const DailyQuizScreen({super.key, this.random});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  late final QuestionRepository _questions;
  late final ProgressRepository _progress;
  late final Random _random;

  Question? _current;

  /// Orden en pantalla de las opciones: _optionOrder[posición] = índice real.
  List<int> _optionOrder = const [];

  /// Opción elegida (índice real), para pintarla al corregir.
  int? _selectedOption;

  /// true después de responder: la corrección queda en pantalla hasta tocar
  /// "Continuar". Mientras tanto no se muestra el trofeo aunque se haya
  /// llegado a la meta, para que la última pregunta del día también se corrija.
  bool _reviewing = false;
  bool _lastAnswerCorrect = false;

  String? _modeMessage;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    _questions = context.read<QuestionRepository>();
    _progress = context.read<ProgressRepository>();
    _random = widget.random ?? Random();
    // Si la app quedó abierta de un día para otro, reinicia el contador antes
    // de decidir si la meta ya está cumplida.
    _progress.rolloverIfNewDay();
    _pickNextQuestion();
  }

  /// Elige la próxima pregunta. No llama a setState: lo hace quien la usa.
  void _pickNextQuestion() {
    _reviewing = false;
    _selectedOption = null;
    if (_questions.isEmpty) return;

    final progress = _progress.progress;
    var candidates = _questions.all;
    String? modeMessage;

    // Quitamos las categorías desactivadas en Configuración
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
          modeMessage = "📚 Modo Examen: ${progress.targetCategory}";
        }
      }
    }

    if (candidates.isEmpty) {
      _current = null;
      _emptyMessage = 'No hay preguntas habilitadas.\nRevisá las materias activas en Configuración.';
      return;
    }

    // Con más de una disponible, no se repite la que acaba de salir.
    final previous = _current;
    if (previous != null && candidates.length > 1) {
      candidates = candidates.where((q) => q.id != previous.id).toList();
    }

    // Selección ponderada: las que más se fallaron salen más seguido.
    final weighted = <Question>[];
    for (final q in candidates) {
      final weight = min(1 + q.errorCount * 2, 10);
      weighted.addAll(List.filled(weight, q));
    }

    final next = weighted[_random.nextInt(weighted.length)];
    _current = next;
    _modeMessage = modeMessage;
    // Las opciones se muestran mezcladas para que no se memorice la posición.
    _optionOrder = List.generate(next.options.length, (i) => i)..shuffle(_random);
  }

  /// Registra el resultado y deja la pregunta en pantalla con la corrección.
  void _submit(bool correct) {
    final q = _current!;
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }

    _questions.recordAnswer(q, correct: correct);
    _progress.incrementProgress(correct);

    setState(() {
      _reviewing = true;
      _lastAnswerCorrect = correct;
    });
  }

  void _answerOption(int optionIndex) {
    _selectedOption = optionIndex;
    _submit(optionIndex == _current!.correctAnswerIndex);
  }

  void _continue() {
    setState(() {
      final p = _progress.progress;
      if (p.answeredToday >= p.dailyGoal) {
        // Se muestra el trofeo.
        _reviewing = false;
      } else {
        _pickNextQuestion();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return const _EmptyQuiz(message: 'Agregá preguntas para empezar ✍️');
    final q = _current;
    if (q == null) return _EmptyQuiz(message: _emptyMessage ?? 'No hay preguntas disponibles.');

    final p = context.watch<ProgressRepository>().progress;

    if (!_reviewing && p.answeredToday >= p.dailyGoal) {
      return _GoalReached(streak: p.streak);
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Text('${p.answeredToday}/${p.dailyGoal}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          )
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (p.answeredToday / p.dailyGoal).clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            color: AppColors.teal,
            minHeight: 6,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuestionCard(question: q),
                  const SizedBox(height: 24),
                  ..._buildOptions(q),
                  if (_reviewing) ...[
                    const SizedBox(height: 8),
                    _Feedback(correct: _lastAnswerCorrect, explanation: q.explanation),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _reviewing
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          : null,
    );
  }

  List<Widget> _buildOptions(Question q) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      for (var position = 0; position < _optionOrder.length; position++)
        _buildOption(q, position, _optionOrder[position], isDark),
    ];
  }

  Widget _buildOption(Question q, int position, int optionIndex, bool isDark) {
    final isCorrect = optionIndex == q.correctAnswerIndex;
    final isSelected = optionIndex == _selectedOption;

    Color bgColor = Theme.of(context).cardColor;
    Color borderColor = Colors.transparent;
    Color? textColor; // null: usa el color del tema

    if (_reviewing) {
      if (isCorrect) {
        bgColor = AppColors.teal.withValues(alpha: 0.2);
        borderColor = AppColors.teal;
        textColor = isDark ? AppColors.teal : AppColors.tealDark;
      } else if (isSelected) {
        bgColor = AppColors.pink.withValues(alpha: 0.2);
        borderColor = AppColors.pink;
        textColor = isDark ? AppColors.pink : AppColors.darkRed;
      } else {
        bgColor = Theme.of(context).cardColor.withValues(alpha: 0.5); // Deshabilitado visualmente
        textColor = Colors.grey;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _reviewing ? null : () => _answerOption(optionIndex),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              if (!_reviewing) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _reviewing && isCorrect ? AppColors.teal : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + position), // A, B, C... según la posición en pantalla
                    style: TextStyle(fontWeight: FontWeight.bold, color: _reviewing && isCorrect ? Colors.white : Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  q.options[optionIndex],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                ),
              ),
              if (_reviewing && isCorrect) const Icon(Icons.check_circle, color: AppColors.teal),
              if (_reviewing && isSelected && !isCorrect) const Icon(Icons.cancel, color: AppColors.pink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enunciado, imagen opcional y materia.
class _QuestionCard extends StatelessWidget {
  final Question question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          if (q.imagePath != null) ...[
            QuestionImage(
              imageRef: q.imagePath,
              height: 180,
              width: double.infinity,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            q.questionText,
            textAlign: TextAlign.center,
            // La familia (Poppins) viene del textTheme de la app.
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(q.category, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Resultado de la respuesta y la explicación, debajo de la pregunta.
class _Feedback extends StatelessWidget {
  final bool correct;
  final String? explanation;
  const _Feedback({required this.correct, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.teal : AppColors.pink;
    final text = explanation?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Text(
                correct ? '¡Correcto!' : 'Incorrecto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (text.isNotEmpty)
            Text(text, style: const TextStyle(fontSize: 15))
          else
            Text(
              correct ? 'Sumaste una más a tu meta de hoy.' : 'La vamos a repasar más seguido.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _GoalReached extends StatelessWidget {
  final int streak;
  const _GoalReached({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.teal],
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
              const Text('¡Meta diaria cumplida!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                'Racha actual: $streak ${streak == 1 ? 'día' : 'días'} 🔥',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
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
}

/// Pantalla sin preguntas para jugar, con AppBar para poder volver.
class _EmptyQuiz extends StatelessWidget {
  final String message;
  const _EmptyQuiz({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Diario', style: TextStyle(fontSize: 18))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
