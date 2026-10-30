import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_progress.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'add_question_screen.dart';
import 'ai_generator_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<UserProgress>(HiveBoxes.progress).listenable(),
      builder: (context, Box<UserProgress> box, _) {
        final p = box.getAt(0)!;
        final displayName = p.userName.isEmpty ? "Estudiante" : p.userName;

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
                        _Header(displayName: displayName),
                        const SizedBox(height: 24),
                        _ProgressCard(progress: p),
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
                      _MenuCard(
                        title: "Quiz Diario",
                        subtitle: "¡A jugar!",
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.primary,
                        onTap: () => Navigator.pushNamed(context, '/quiz'),
                      ),
                      _MenuCard(
                        title: "Crear con IA",
                        subtitle: "Mágico ✨",
                        icon: Icons.auto_awesome,
                        color: AppColors.pink,
                        onTap: () => _push(context, const AiGeneratorScreen()),
                      ),
                      _MenuCard(
                        title: "Agregar",
                        subtitle: "Manual",
                        icon: Icons.add_circle_outline,
                        color: AppColors.teal,
                        onTap: () => _push(context, const AddQuestionScreen()),
                      ),
                      _MenuCard(
                        title: "Banco",
                        subtitle: "Ver todas",
                        icon: Icons.grid_view_rounded,
                        color: AppColors.amber,
                        onTap: () => Navigator.pushNamed(context, '/questions'),
                      ),
                      _MenuCard(
                        title: "Perfil",
                        subtitle: "Estadísticas",
                        icon: Icons.person_outline,
                        color: AppColors.tealDark,
                        onTap: () => _push(context, const ProfileScreen()),
                      ),
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
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Header extends StatelessWidget {
  final String displayName;
  const _Header({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¡Hola, $displayName! 👋",
              style: GoogleFonts.poppins(fontSize: 16, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 4),
            const Text("Vamos a aprender", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta con las respuestas de hoy contra la meta diaria y la racha.
class _ProgressCard extends StatelessWidget {
  final UserProgress progress;
  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final ratio = p.dailyGoal > 0 ? p.answeredToday / p.dailyGoal : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 8))],
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
                    Text(
                      "${p.answeredToday}",
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        "/ ${p.dailyGoal} preguntas",
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 28),
                const SizedBox(height: 4),
                Text(
                  "${p.streak}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Text("Racha", style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
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

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
