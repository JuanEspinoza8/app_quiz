import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progressBox = Hive.box<UserProgress>('progressBox');
    final questionBox = Hive.box<Question>('questionsBox');
    final statsBox = Hive.box<DailyStats>('statsBox');

    final userProgress = progressBox.getAt(0)!;
    final allQuestions = questionBox.values.toList();

    int totalAnswered = 0;
    int totalErrors = 0;
    Map<String, List<Question>> questionsByCategory = {};

    for (var q in allQuestions) {
      if (q.totalAttempts > 0) {
        totalAnswered += q.totalAttempts;
        totalErrors += q.errorCount;
      }
      if (!questionsByCategory.containsKey(q.category)) {
        questionsByCategory[q.category] = [];
      }
      questionsByCategory[q.category]!.add(q);
    }

    final totalCorrect = totalAnswered - totalErrors;
    final globalAccuracy = totalAnswered == 0 ? 0.0 : (totalCorrect / totalAnswered);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Progreso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen General
            _buildSummaryRow(context, userProgress, totalAnswered, globalAccuracy),

            const SizedBox(height: 30),

            // Gráfico Semanal
            Text("Tu semana", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              height: 250, // 👈 AUMENTAMOS UN POCO LA ALTURA TOTAL
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: _buildWeeklyChart(statsBox, context),
            ),

            const SizedBox(height: 30),

            // Rendimiento por Materia
            Text("Por materia", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildCategoryStats(context, questionsByCategory),

            const SizedBox(height: 30),

            // Logros
            Text("Tus Logros", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildAchievementsGrid(context, userProgress, totalAnswered, globalAccuracy, allQuestions.length),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, UserProgress progress, int totalAnswered, double accuracy) {
    return Row(
      children: [
        Expanded(child: _statCard(context, "Racha", "${progress.streak} días", Icons.local_fire_department, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(context, "Total", "$totalAnswered", Icons.check_circle_outline, const Color(0xFF6C63FF))),
        const SizedBox(width: 12),
        Expanded(child: _statCard(context, "Precisión", "${(accuracy * 100).toStringAsFixed(0)}%", Icons.pie_chart_outline, const Color(0xFF4ECDC4))),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(Box<DailyStats> statsBox, BuildContext context) {
    final now = DateTime.now();
    final List<DailyStats?> weekData = [];
    final List<String> weekDays = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      try {
        final stat = statsBox.values.firstWhere(
              (s) => s.date.year == date.year && s.date.month == date.month && s.date.day == date.day,
        );
        weekData.add(stat);
      } catch (e) {
        weekData.add(null);
      }
      weekDays.add(DateFormat.E('es').format(date).substring(0, 1).toUpperCase());
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => const Color(0xFF6C63FF)),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40, // 👈 ESTO ES LO QUE FALTABA: Espacio reservado para las letras
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(weekDays[val.toInt()], style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: weekData.asMap().entries.map((entry) {
          final total = entry.value?.questionsAnswered.toDouble() ?? 0.0;
          final correct = entry.value?.correctAnswers.toDouble() ?? 0.0;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: total == 0 ? 0.5 : total,
                color: Colors.grey.withOpacity(0.2),
                width: 14,
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [
                  BarChartRodStackItem(0, correct, const Color(0xFF6C63FF)),
                  BarChartRodStackItem(correct, total, const Color(0xFF6C63FF).withOpacity(0.3)),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryStats(BuildContext context, Map<String, List<Question>> grouped) {
    if (grouped.isEmpty) return const Text("Juega un poco para ver datos.");

    return Column(
      children: grouped.entries.map((entry) {
        final category = entry.key;
        final questions = entry.value;
        int attempts = 0;
        int errors = 0;
        for (var q in questions) {
          attempts += q.totalAttempts;
          errors += q.errorCount;
        }
        if (attempts == 0) return const SizedBox.shrink();
        final accuracy = (attempts - errors) / attempts;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("${(accuracy * 100).toStringAsFixed(0)}%", style: TextStyle(color: _getColorForAccuracy(accuracy), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: accuracy,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  color: _getColorForAccuracy(accuracy),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getColorForAccuracy(double accuracy) {
    if (accuracy >= 0.8) return const Color(0xFF4ECDC4);
    if (accuracy >= 0.5) return Colors.orangeAccent;
    return const Color(0xFFFF6584);
  }

  Widget _buildAchievementsGrid(BuildContext context, UserProgress p, int totalAnswered, double accuracy, int totalQuestions) {
    final achievements = [
      {"icon": Icons.school, "title": "Novato", "desc": "10 respuestas", "unlocked": totalAnswered >= 10},
      {"icon": Icons.local_fire_department, "title": "En llamas", "desc": "Racha de 3", "unlocked": p.streak >= 3},
      {"icon": Icons.emoji_events, "title": "Experto", "desc": "100 respuestas", "unlocked": totalAnswered >= 100},
      {"icon": Icons.psychology, "title": "Cerebrito", "desc": "80% precisión", "unlocked": totalAnswered >= 20 && accuracy >= 0.8},
      {"icon": Icons.edit_note, "title": "Creador", "desc": "5 preguntas", "unlocked": totalQuestions >= 5},
      {"icon": Icons.diamond, "title": "Leyenda", "desc": "Racha de 30", "unlocked": p.streak >= 30},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final item = achievements[index];
        final isUnlocked = item['unlocked'] as bool;
        return Tooltip(
          message: "${item['desc']}",
          triggerMode: TooltipTriggerMode.tap,
          child: Container(
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFFFFBC42) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isUnlocked
                  ? [BoxShadow(color: const Color(0xFFFFBC42).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, size: 32, color: isUnlocked ? Colors.white : Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.white : Colors.grey.shade400),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}