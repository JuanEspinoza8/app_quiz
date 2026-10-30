import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

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
import 'package:quiz_daily/services/progress_service.dart';
import 'package:quiz_daily/services/storage_service.dart';
import 'package:quiz_daily/theme/app_colors.dart';

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

  final progressBox = Hive.box<UserProgress>(HiveBoxes.progress);

  // Inicialización de primera vez
  if (progressBox.isEmpty) {
    await progressBox.add(UserProgress(
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

  // Reinicia el progreso diario y la racha si cambió el día desde la última vez.
  ProgressService().rolloverIfNewDay();

  try {
    await NotificationService.init();

    // Reprogramamos el recordatorio al iniciar por si el sistema lo canceló
    // (pasa en algunas capas de Android con ahorro de batería agresivo).
    final userPrefs = progressBox.getAt(0)!;
    await NotificationService.scheduleDaily(userPrefs.notificationHour, userPrefs.notificationMinute);
  } catch (e, stack) {
    // Un problema con las notificaciones no tiene que impedir usar la app.
    debugPrint('No se pudieron configurar las notificaciones: $e\n$stack');
  }

  runApp(const QuizDailyApp());
}

class QuizDailyApp extends StatelessWidget {
  const QuizDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<UserProgress>(HiveBoxes.progress).listenable(),
      builder: (context, Box<UserProgress> box, _) {
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
      },
    );
  }

  static AppBarTheme _appBarTheme(Color foreground) => AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: foreground, fontSize: 24, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: foreground),
      );
}