import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:provider/provider.dart';

import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/screens/home_screen.dart';
import 'package:quiz_daily/screens/settings_screen.dart';
import 'package:quiz_daily/screens/onboarding_screen.dart';
import 'package:quiz_daily/screens/storage_error_screen.dart';
import 'package:quiz_daily/services/notification_service.dart';
import 'package:quiz_daily/services/storage_service.dart';
import 'package:quiz_daily/theme/app_colors.dart';
import 'package:quiz_daily/widgets/day_rollover_on_resume.dart';

Future<void> main() async {
  // Aseguramos que el motor gráfico esté listo antes de cualquier lógica
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos formato de fechas para gráficos en español
  await initializeDateFormatting('es', null);

  await Hive.initFlutter();
  Hive.registerAdapter(QuestionAdapter());
  Hive.registerAdapter(UserProgressAdapter());
  Hive.registerAdapter(DailyStatsAdapter());

  await _start();
}

/// Abre los datos y arranca la app. Si Hive no puede abrir alguna caja, se
/// muestra una pantalla de error en lugar de borrar los datos.
Future<void> _start() async {
  final failures = await StorageService.openBoxes();
  if (failures.isNotEmpty) {
    runApp(StorageErrorApp(failures: failures, onRetry: _start));
    return;
  }

  // Las pantallas acceden a los datos solo a través de estos repositorios,
  // que se comparten con Provider.
  final questions = QuestionRepository(Hive.box<Question>(HiveBoxes.questions));
  final progress = ProgressRepository(
    Hive.box<UserProgress>(HiveBoxes.progress),
    Hive.box<DailyStats>(HiveBoxes.stats),
  );
  await progress.ensureInitialized();

  // Reinicia el progreso diario y la racha si cambió el día desde la última vez.
  progress.rolloverIfNewDay();

  try {
    await NotificationService.init();

    // Reprogramamos el recordatorio al iniciar por si el sistema lo canceló
    // (pasa en algunas capas de Android con ahorro de batería agresivo).
    final userPrefs = progress.progress;
    await NotificationService.scheduleDaily(userPrefs.notificationHour, userPrefs.notificationMinute);
  } catch (e, stack) {
    // Un problema con las notificaciones no tiene que impedir usar la app.
    debugPrint('No se pudieron configurar las notificaciones: $e\n$stack');
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: questions),
      ChangeNotifierProvider.value(value: progress),
    ],
    child: const DayRolloverOnResume(child: QuizDailyApp()),
  ));
}

class QuizDailyApp extends StatelessWidget {
  const QuizDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // select: el MaterialApp solo se reconstruye si cambian estos dos valores,
    // no con cada respuesta del quiz.
    final isDark = context.select<ProgressRepository, bool>((r) => r.progress.isDarkMode);
    final showOnboarding = context.select<ProgressRepository, bool>((r) => r.progress.userName.isEmpty);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quiz Daily',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

      // TEMA CLARO
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
        scaffoldBackgroundColor: AppColors.lightBackground,
        cardColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: _appBarTheme(Colors.black87),
      ),

      // TEMA OSCURO
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark, surface: AppColors.darkSurface),
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardColor: AppColors.darkSurface,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: _appBarTheme(Colors.white),
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
  }

  static AppBarTheme _appBarTheme(Color foreground) => AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: foreground, fontSize: 24, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: foreground),
        // Con fondo transparente, el AppBar no sabe de qué color poner los
        // íconos de la barra de estado: se fijan según el tema.
        systemOverlayStyle: foreground == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      );
}