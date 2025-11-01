import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/add_question_screen.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 🧩 Registro de adaptadores Hive
  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(UserProgressAdapter());

  // 📦 Apertura de cajas
  await Hive.openBox<Question>('questionsBox');
  await Hive.openBox<UserProgress>('progressBox');

  // 🔔 Inicialización de notificaciones
  await NotificationService.init();

  // ⚙️ Programa notificación diaria a las 21:35
  final now = DateTime.now();
  // 🔸 Esto hace que si ejecutás la app a las 21:34, se programe para dentro de 1 minuto.
  await NotificationService.scheduleDaily(now.hour, now.minute + 1);

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
      home: const HomeScreen(),
      routes: {
        '/questions': (context) => const QuestionsListScreen(),
        '/goal': (context) => const DailyGoalScreen(),
        '/quiz': (context) => const DailyQuizScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Daily')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                onPressed: () => Navigator.pushNamed(context, '/questions'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.flag),
                label: const Text('Mi meta y racha'),
                onPressed: () => Navigator.pushNamed(context, '/goal'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.quiz),
                label: const Text('Quiz Diario'),
                onPressed: () => Navigator.pushNamed(context, '/quiz'),
              ),
              const SizedBox(height: 32),
              // 🔔 Botón de test de notificación
              ElevatedButton(
                onPressed: () async {
                  await NotificationService.showNow(
                    "Test",
                    "Esta es una prueba 💬",
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                ),
                child: const Text(
                  "Probar notificación ahora",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
