import 'package:flutter/material.dart';
import 'package:quiz_daily/screens/add_question_screen.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart'; // 👈 este import es necesario

void main() {
  runApp(const QuizDailyApp());
}

class QuizDailyApp extends StatelessWidget {
  const QuizDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quiz Daily',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PlaceholderScreen(),
      routes: {
        '/questions': (context) => const QuestionsListScreen(), //
      },
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Daily')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar pregunta'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddQuestionScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('Ver preguntas'),
              onPressed: () {
                Navigator.pushNamed(context, '/questions'); // 👈 usa la ruta declarada arriba
              },
            ),
          ],
        ),
      ),
    );
  }
}
