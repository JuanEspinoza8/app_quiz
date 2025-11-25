import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // 👈 Fuente bonita
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';

// Imports de tus modelos y pantallas
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/screens/add_question_screen.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/screens/profile_screen.dart';
import 'package:quiz_daily/screens/ai_generator_screen.dart';
import 'package:quiz_daily/screens/settings_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Hive.initFlutter();

  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(UserProgressAdapter());
  Hive.registerAdapter(DailyStatsAdapter());

  await Hive.openBox<Question>('questionsBox');
  final progressBox = await Hive.openBox<UserProgress>('progressBox');
  await Hive.openBox<DailyStats>('statsBox');

  if (progressBox.isEmpty) {
    progressBox.add(UserProgress(
      dailyGoal: 3,
      answeredToday: 0,
      streak: 0,
      lastPlayedDate: DateTime(2000, 1, 1),
      notificationHour: 18,
      notificationMinute: 0,
    ));
  }

  await NotificationService.init();

  final userPrefs = progressBox.getAt(0)!;
  await NotificationService.scheduleDaily(
      userPrefs.notificationHour,
      userPrefs.notificationMinute
  );

  runApp(const QuizDailyApp());
}

class QuizDailyApp extends StatelessWidget {
  const QuizDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quiz Daily',
      // 👇 TEMA BONITO Y MODERNO
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF), // Un violeta moderno
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5FA), // Gris muy suave de fondo
        textTheme: GoogleFonts.poppinsTextTheme(), // Tipografía Poppins
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/questions': (_) => const QuestionsListScreen(),
        '/goal': (_) => const DailyGoalScreen(),
        '/quiz': (_) => const DailyQuizScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos cambios en el progreso para actualizar la tarjeta de resumen
    return ValueListenableBuilder(
      valueListenable: Hive.box<UserProgress>('progressBox').listenable(),
      builder: (context, Box<UserProgress> box, _) {
        final p = box.getAt(0)!;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. HEADER CON SALUDO Y RESUMEN
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("¡Hola, Estudiante! 👋", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                const Text("Vamos a aprender", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            // Botón de ajustes (Tuerca) pequeño y elegante
                            Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                onPressed: () => Navigator.pushNamed(context, '/settings'),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        // TARJETA DE RESUMEN DIARIO
                        _buildProgressCard(context, p),
                      ],
                    ),
                  ),
                ),

                // 2. GRID DE MENÚ (BOTONES)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1, // Hacemos las tarjetas un poco más cuadraditas
                    children: [
                      // Jugar (Destacado)
                      _MenuCard(
                        title: "Quiz Diario",
                        subtitle: "¡A jugar!",
                        icon: Icons.play_arrow_rounded,
                        color: const Color(0xFF6C63FF), // Violeta principal
                        isPrimary: true,
                        onTap: () => Navigator.pushNamed(context, '/quiz'),
                      ),
                      // IA (Mágico)
                      _MenuCard(
                        title: "Crear con IA",
                        subtitle: "Mágico ✨",
                        icon: Icons.auto_awesome,
                        color: const Color(0xFFFF6584), // Rosa vibrante
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AiGeneratorScreen()));
                        },
                      ),
                      // Agregar Manual
                      _MenuCard(
                        title: "Agregar",
                        subtitle: "Manual",
                        icon: Icons.add_circle_outline,
                        color: const Color(0xFF4ECDC4), // Turquesa
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuestionScreen()));
                        },
                      ),
                      // Ver Lista
                      _MenuCard(
                        title: "Banco",
                        subtitle: "Ver todas",
                        icon: Icons.grid_view_rounded,
                        color: const Color(0xFFFFBC42), // Amarillo
                        onTap: () => Navigator.pushNamed(context, '/questions'),
                      ),
                      // Perfil
                      _MenuCard(
                        title: "Perfil",
                        subtitle: "Estadísticas",
                        icon: Icons.person_outline,
                        color: const Color(0xFF1A535C), // Verde oscuro
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                        },
                      ),
                      // Metas
                      _MenuCard(
                        title: "Metas",
                        subtitle: "Configurar",
                        icon: Icons.flag_outlined,
                        color: Colors.indigo,
                        onTap: () => Navigator.pushNamed(context, '/goal'),
                      ),
                    ],
                  ),
                ),

                // Espacio extra abajo
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(BuildContext context, UserProgress p) {
    final double progress = (p.dailyGoal > 0) ? (p.answeredToday / p.dailyGoal) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tu progreso hoy", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${p.answeredToday}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text("/ ${p.dailyGoal} preguntas", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress > 1 ? 1 : progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Racha Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 28),
                const SizedBox(height: 4),
                Text("${p.streak}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const Text("Racha", style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Widget personalizado para las tarjetas del menú
class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0, // Quitamos elevación por defecto para usar sombras custom
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icono con fondo suave
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),

                // Textos
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}