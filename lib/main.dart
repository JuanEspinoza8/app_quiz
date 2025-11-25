import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 1. IMPORT NECESARIO

// Imports de tus modelos y pantallas
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/models/daily_stats.dart'; // Importamos el nuevo modelo
import 'package:quiz_daily/screens/add_question_screen.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/screens/profile_screen.dart';
import 'package:quiz_daily/screens/ai_generator_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';
import 'package:quiz_daily/services/data_sync_service.dart';
import 'package:quiz_daily/services/import_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 2. INICIALIZAMOS EL FORMATO DE FECHAS (ESPAÑOL)
  await initializeDateFormatting('es', null);

  await Hive.initFlutter();

  // Registramos los adaptadores de Hive
  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(UserProgressAdapter());
  Hive.registerAdapter(DailyStatsAdapter());

  // Abrimos las cajas de datos
  await Hive.openBox<Question>('questionsBox');
  await Hive.openBox<UserProgress>('progressBox');
  await Hive.openBox<DailyStats>('statsBox');

  // Inicializamos notificaciones
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
      appBar: AppBar(title: const Text('Quiz Daily 📚')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. BOTÓN PRINCIPAL: Jugar
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 32),
                  label: const Text('Jugar Quiz Diario', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple.shade100,
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/quiz'),
                ),
                const SizedBox(height: 24),

                // 2. GENERADOR CON IA (MÁGICO) ✨
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text('Crear con IA (Mágico) ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple, // Color destacado
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiGeneratorScreen()),
                      );
                    },
                  ),
                ),

                // 3. GESTIÓN MANUAL: Agregar y Ver lista
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Manual'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddQuestionScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.list),
                        label: const Text('Ver Lista'),
                        onPressed: () => Navigator.pushNamed(context, '/questions'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. PROGRESO Y CONFIGURACIÓN
                ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Mi Perfil y Logros 🏆'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Meta y Modo Examen'),
                  onPressed: () => Navigator.pushNamed(context, '/goal'),
                ),

                const Divider(height: 32),

                // 5. DATOS: Importar y Exportar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text("Importar"),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );

                        if (result == null) return;

                        final file = File(result.files.single.path!);
                        final count = await ImportService.importQuestions(file);

                        if(context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Se importaron $count preguntas 📚")),
                          );
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text("Exportar"),
                      onPressed: () async {
                        final path = await DataSyncService.exportQuestions();
                        await Share.shareXFiles([XFile(path)], text: "Mis preguntas 📚");
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}