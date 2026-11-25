import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/ai_generator_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  UserProgress progress() => UserProgress(dailyGoal: 5, answeredToday: 0, streak: 0, lastPlayedDate: DateTime(2026, 10, 30));

  /// Generador de prueba: devuelve dos preguntas sin llamar a Gemini.
  Future<List<Question>> fakeGenerate(
    String promptText, {
    required String userCategory,
    List<String>? avoidQuestions,
    Uint8List? fileBytes,
    String? mimeType,
  }) async =>
      [
        for (final n in [1, 2])
          Question(
            id: 'ia$n',
            questionText: 'Generada $n',
            options: ['A$n', 'B$n', 'C$n', 'D$n'],
            correctAnswerIndex: 0,
            category: userCategory,
            createdAt: DateTime(2026, 11, 1),
          ),
      ];

  testWidgets('se puede descartar una pregunta generada y la materia se une a la existente', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress(), questions: [testQuestion('1', category: 'Biología')]);
    await pushScreen(tester, repos, AiGeneratorScreen(generate: fakeGenerate));

    await tester.enterText(find.byType(TextField).first, 'biología');
    await tester.enterText(find.byType(TextField).last, 'La célula es la unidad básica de la vida.');
    await tester.tap(find.text('Generar Preguntas'));
    await tester.pumpAndSettle();

    expect(find.text('Vista Previa (2)'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Descartar pregunta 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Descartar pregunta 1'));
    await tester.pumpAndSettle();
    expect(find.text('Vista Previa (1)'), findsOneWidget);
    expect(find.text('Generada 1'), findsNothing);

    await tester.ensureVisible(find.text('GUARDAR TODO'));
    await tester.tap(find.text('GUARDAR TODO'));
    await tester.pumpAndSettle();

    final saved = repos.questions.all.where((q) => q.id.startsWith('ia')).toList();
    expect(saved.map((q) => q.questionText), ['Generada 2']);
    expect(saved.single.category, 'Biología');
  });

  testWidgets('el diálogo de edición no deja guardar una opción vacía', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    final question = Question(
      id: 'ia1',
      questionText: 'Generada',
      options: ['A', 'B', 'C', 'D'],
      correctAnswerIndex: 0,
      category: 'X',
      createdAt: DateTime(2026),
    );
    Question? result;
    await tester.pumpWidget(repos.wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showDialog<Question>(
          context: context,
          builder: (_) => EditGeneratedQuestionDialog(question: question),
        ),
        child: const Text('editar'),
      ),
    )));
    await tester.tap(find.text('editar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('ai-option-2')), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Completá todas las opciones'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ai-option-2')), 'C bis');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result!.options, ['A', 'B', 'C bis', 'D']);
    expect(result!.id, 'ia1');
  });
}
