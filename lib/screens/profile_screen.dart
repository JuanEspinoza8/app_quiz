import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // 👈 Necesario para los gráficos
import 'package:intl/intl.dart';         // 👈 Necesario para las fechas
import '../models/question.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';     // 👈 Importamos el nuevo modelo

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accedemos a las 3 cajas de datos
    final progressBox = Hive.box<UserProgress>('progressBox');
    final questionBox = Hive.box<Question>('questionsBox');
    final statsBox = Hive.box<DailyStats>('statsBox'); // 👈 Caja de historial

    final userProgress = progressBox.getAt(0)!;
    final allQuestions = questionBox.values.toList();

    // 📊 CÁLCULO DE ESTADÍSTICAS GENERALES
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
      appBar: AppBar(title: const Text('Mi Perfil y Estadísticas 📊')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. RESUMEN GENERAL
            _buildSummaryCard(userProgress, totalAnswered, globalAccuracy),

            const SizedBox(height: 24),

            // 2. GRÁFICO SEMANAL (NUEVO) 📈
            const Text("📅 Tu semana de estudio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Preguntas respondidas (Total vs Correctas)", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              height: 200, // Altura del gráfico
              padding: const EdgeInsets.only(right: 16),
              child: _buildWeeklyChart(statsBox),
            ),

            const SizedBox(height: 24),

            // 3. RENDIMIENTO POR MATERIA
            const Text("🧠 Rendimiento por Materia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildCategoryStats(questionsByCategory),

            const SizedBox(height: 24),

            // 4. LOGROS
            const Text("🎖️ Vitrina de Trofeos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAchievementsGrid(userProgress, totalAnswered, globalAccuracy, allQuestions.length),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DEL GRÁFICO ---
  Widget _buildWeeklyChart(Box<DailyStats> statsBox) {
    // Obtenemos los últimos 7 días
    final now = DateTime.now();
    final List<DailyStats?> weekData = [];
    final List<String> weekDays = [];

    // Generamos datos de hoy hacia atrás (7 días)
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Buscamos si hay datos para ese día
      try {
        final stat = statsBox.values.firstWhere(
              (s) => s.date.year == date.year && s.date.month == date.month && s.date.day == date.day,
        );
        weekData.add(stat);
      } catch (e) {
        weekData.add(null); // No jugó ese día
      }
      // Nombre del día (Lun, Mar...)
      weekDays.add(DateFormat.E('es').format(date)); // Requiere inicializar locale, o usará default
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20, // Altura fija o dinámica según tus datos
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < weekDays.length) {
                  // Tomamos la inicial del día
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      weekDays[index][0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Ocultamos eje Y
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: weekData.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final total = stat?.questionsAnswered.toDouble() ?? 0.0;
          final correct = stat?.correctAnswers.toDouble() ?? 0.0;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total == 0 ? 0.5 : total, // Si es 0 ponemos un poquito para que se vea la base
                color: Colors.deepPurple.shade100,
                width: 16,
                borderRadius: BorderRadius.circular(4),
                // Stacked rod para mostrar correctas encima (simulado con background)
                rodStackItems: [
                  BarChartRodStackItem(0, correct, Colors.green),
                  BarChartRodStackItem(correct, total, Colors.deepPurple.shade100),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ... (El resto de métodos _buildSummaryCard, _buildCategoryStats y _buildAchievementsGrid
  // ... son iguales a los que tenías antes. Si quieres te los pego de nuevo abajo para asegurar).

  Widget _buildSummaryCard(UserProgress progress, int totalAnswered, double accuracy) {
    return Card(
      elevation: 4,
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem("🔥 Racha", "${progress.streak} días"),
            _statItem("📚 Total", "$totalAnswered"),
            _statItem("🎯 Precisión", "${(accuracy * 100).toStringAsFixed(0)}%"),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCategoryStats(Map<String, List<Question>> grouped) {
    if (grouped.isEmpty) return const Text("Juega un poco para ver estadísticas.");

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

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text("${(accuracy * 100).toStringAsFixed(0)}%"),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: accuracy,
                backgroundColor: Colors.grey.shade200,
                color: _getColorForAccuracy(accuracy),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getColorForAccuracy(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAchievementsGrid(UserProgress p, int totalAnswered, double accuracy, int totalQuestions) {
    final achievements = [
      {"icon": Icons.school, "title": "Novato", "desc": "Responde 10 preguntas", "unlocked": totalAnswered >= 10},
      {"icon": Icons.local_fire_department, "title": "En llamas", "desc": "Racha de 3 días", "unlocked": p.streak >= 3},
      {"icon": Icons.emoji_events, "title": "Experto", "desc": "Responde 100 preguntas", "unlocked": totalAnswered >= 100},
      {"icon": Icons.psychology, "title": "Cerebrito", "desc": "80% precisión (min 20 resp)", "unlocked": totalAnswered >= 20 && accuracy >= 0.8},
      {"icon": Icons.edit_note, "title": "Creador", "desc": "Crea 5 preguntas", "unlocked": totalQuestions >= 5},
      {"icon": Icons.diamond, "title": "Leyenda", "desc": "Racha de 30 días", "unlocked": p.streak >= 30},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
              color: isUnlocked ? Colors.amber.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: isUnlocked ? Border.all(color: Colors.amber, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, size: 32, color: isUnlocked ? Colors.orange[800] : Colors.grey),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.black : Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}