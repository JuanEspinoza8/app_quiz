import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:quiz_daily/screens/onboarding_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';

void main() async {
  // Aseguramos que el motor gráfico esté listo antes de cualquier lógica
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializamos formato de fechas para gráficos en español
    await initializeDateFormatting('es', null);

    // Inicializamos Hive
    await Hive.initFlutter();

    // Registramos adaptadores (Tipos de datos custom)
    Hive.registerAdapter(QuestionAdapter());
    Hive.registerAdapter(UserProgressAdapter());
    Hive.registerAdapter(DailyStatsAdapter());

    // 👇 BLOQUE DE SEGURIDAD ANTI-PANTALLA NEGRA
    // Intentamos abrir las cajas. Si falla por un bloqueo (.lock), capturamos el error.
    try {
      await Hive.openBox<Question>('questionsBox');
      await Hive.openBox<UserProgress>('progressBox');
      await Hive.openBox<DailyStats>('statsBox');
    } catch (e) {
      print("⚠️ Error crítico abriendo Hive (posible lock corrupto): $e");

      // Si falla, intentamos borrar los archivos de la caja corrupta de la memoria y reabrir.
      // Esto elimina los archivos .lock que causan que la app se cuelgue.
      try {
        await Hive.deleteBoxFromDisk('questionsBox'); // Solo si es necesario borrar datos corruptos
        await Hive.deleteBoxFromDisk('progressBox');
        await Hive.deleteBoxFromDisk('statsBox');
      } catch (e2) {
        print("Error intentando borrar cajas corruptas: $e2");
      }

      // Reintentamos abrir las cajas limpias
      await Hive.openBox<Question>('questionsBox');
      await Hive.openBox<UserProgress>('progressBox');
      await Hive.openBox<DailyStats>('statsBox');
    }

    final progressBox = Hive.box<UserProgress>('progressBox');

    // Inicialización de primera vez (Si la caja está vacía o se reseteó)
    if (progressBox.isEmpty) {
      progressBox.add(UserProgress(
        dailyGoal: 5,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime(2000, 1, 1),
        notificationHour: 18,
        notificationMinute: 0,
        isDarkMode: false,
        userName: '',
        hiddenCategories: [],
      ));
    }

    // Inicializamos notificaciones
    await NotificationService.init();

    // Reprogramamos la notificación al iniciar para "revivirla" si el sistema la mató
    // Esto es CLAVE en Samsung/Xiaomi para que vuelvan a sonar
    final userPrefs = progressBox.getAt(0)!;
    await NotificationService.scheduleDaily(userPrefs.notificationHour, userPrefs.notificationMinute);

  } catch (e, stack) {
    // Si ocurre un error catastrófico que no pudimos manejar, lo imprimimos.
    // En una app real, aquí podrías mandar el error a Crashlytics.
    print("Error fatal en main: $e \n $stack");
  }

  // 👇 runApp SIEMPRE debe ejecutarse al final, pase lo que pase con la BD.
  runApp(const QuizDailyApp());
}

class QuizDailyApp extends StatelessWidget {
  const QuizDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificamos si Hive se cargó correctamente. Si no, mostramos pantalla de carga.
    // Esto evita la pantalla ROJA de error de Flutter.
    if (!Hive.isBoxOpen('progressBox')) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("Recuperando datos...", style: GoogleFonts.poppins()),
              ],
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box<UserProgress>('progressBox').listenable(),
      builder: (context, Box<UserProgress> box, _) {
        // Protección extra por si la caja está vacía tras un error crítico
        if (box.isEmpty) {
          box.add(UserProgress(dailyGoal: 5, answeredToday: 0, streak: 0, lastPlayedDate: DateTime(2000), userName: ''));
        }

        final p = box.getAt(0);
        final isDark = p?.isDarkMode ?? false;
        final bool showOnboarding = (p?.userName == null || p!.userName.isEmpty);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Quiz Daily',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          // TEMA CLARO
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF5F5FA),
            cardColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.black87)),
          ),

          // TEMA OSCURO
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF), brightness: Brightness.dark, surface: const Color(0xFF1E1E1E)),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.white)),
          ),

          home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),

          routes: {
            '/home': (_) => const HomeScreen(),
            '/questions': (_) => const QuestionsListScreen(),
            '/goal': (_) => const DailyGoalScreen(),
            '/quiz': (_) => const DailyQuizScreen(),
            '/settings': (_) => const SettingsScreen(),
          },
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<UserProgress>('progressBox').listenable(),
      builder: (context, Box<UserProgress> box, _) {
        final p = box.getAt(0)!;
        // Si no hay nombre (por error), usamos "Estudiante"
        final displayName = (p.userName.isEmpty) ? "Estudiante" : p.userName;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
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
                                // 👇 AQUÍ SALUDAMOS CON EL NOMBRE
                                Text("¡Hola, $displayName! 👋", style: GoogleFonts.poppins(fontSize: 16, color: Theme.of(context).hintColor)),
                                const SizedBox(height: 4),
                                const Text("Vamos a aprender", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.pushNamed(context, '/settings')),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildProgressCard(context, p),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _MenuCard(title: "Quiz Diario", subtitle: "¡A jugar!", icon: Icons.play_arrow_rounded, color: const Color(0xFF6C63FF), isPrimary: true, onTap: () => Navigator.pushNamed(context, '/quiz')),
                      _MenuCard(title: "Crear con IA", subtitle: "Mágico ✨", icon: Icons.auto_awesome, color: const Color(0xFFFF6584), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiGeneratorScreen()))),
                      _MenuCard(title: "Agregar", subtitle: "Manual", icon: Icons.add_circle_outline, color: const Color(0xFF4ECDC4), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuestionScreen()))),
                      _MenuCard(title: "Banco", subtitle: "Ver todas", icon: Icons.grid_view_rounded, color: const Color(0xFFFFBC42), onTap: () => Navigator.pushNamed(context, '/questions')),
                      _MenuCard(title: "Perfil", subtitle: "Estadísticas", icon: Icons.person_outline, color: const Color(0xFF1A535C), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                      _MenuCard(title: "Metas", subtitle: "Configurar", icon: Icons.flag_outlined, color: Colors.indigo, onTap: () => Navigator.pushNamed(context, '/goal')),
                    ],
                  ),
                ),
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
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 8))]),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Tu progreso hoy", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${p.answeredToday}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text("/ ${p.dailyGoal} preguntas", style: const TextStyle(color: Colors.white70, fontSize: 16)))]), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress > 1 ? 1 : progress, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 6))])),
          const SizedBox(width: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)), child: Column(children: [const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 28), const SizedBox(height: 4), Text("${p.streak}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const Text("Racha", style: TextStyle(color: Colors.white70, fontSize: 10))])),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;
  const _MenuCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap, this.isPrimary = false});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500]))])]),
          ),
        ),
      ),
    );
  }
}