import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/add_question_screen.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';
import 'package:quiz_daily/services/data_sync_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:quiz_daily/services/import_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(UserProgressAdapter());

  await Hive.openBox<Question>('questionsBox');
  await Hive.openBox<UserProgress>('progressBox');

  await NotificationService.init();

  final now = DateTime.now();
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
        '/questions': (_) => const QuestionsListScreen(),
        '/goal': (_) => const DailyGoalScreen(),
        '/quiz': (_) => const DailyQuizScreen(),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Exportar preguntas'),
                onPressed: () async {
                  final path = await DataSyncService.exportQuestions();
                  await Share.shareXFiles([XFile(path)],
                      text: "Mis preguntas del Quiz Daily 📚");
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.input),
                label: const Text("Importar preguntas"),
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );

                  if (result == null) {
                    return; // usuario canceló
                  }

                  final file = File(result.files.single.path!);

                  final count = await ImportService.importQuestions(file);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Se importaron $count preguntas 📚")),
                  );
                },
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await NotificationService.showNow(
                    "Test",
                    "Esta es una prueba 💬",
                  );
                },
                child: const Text("Probar notificación ahora"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
