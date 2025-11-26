import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../models/user_progress.dart';
import '../models/question.dart'; // Importamos modelo Question
import '../services/notification_service.dart';
import '../services/data_sync_service.dart';
import '../services/import_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box<UserProgress> _progressBox;
  late Box<Question> _questionsBox;

  @override
  void initState() {
    super.initState();
    _progressBox = Hive.box<UserProgress>('progressBox');
    _questionsBox = Hive.box<Question>('questionsBox');
  }

  // ... (Tus métodos _pickTime, _backupData, _restoreData se mantienen igual) ...
  // Solo copio los nuevos para ahorrar espacio, pégalos dentro de la clase

  Future<void> _pickTime(UserProgress p) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.notificationHour, minute: p.notificationMinute),
      helpText: "ELIGE LA HORA DEL AVISO",
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6C63FF)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      p.notificationHour = picked.hour;
      p.notificationMinute = picked.minute;
      await p.save();
      await NotificationService.scheduleDaily(picked.hour, picked.minute);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notificación ajustada a las ${picked.format(context)} 📅')));
      setState(() {});
    }
  }

  Future<void> _backupData() async {
    final path = await DataSyncService.exportFullBackup();
    await Share.shareXFiles([XFile(path)], text: "Respaldo Quiz Daily 🔒");
  }

  Future<void> _restoreData() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null) return;
    final file = File(result.files.single.path!);
    final msg = await ImportService.importBackup(file);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    setState(() {});
  }

  void _showCategoryFilter(UserProgress p) {
    final allCategories = _questionsBox.values.map((q) => q.category).toSet().toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Materias Activas", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (allCategories.isEmpty) const Text("No hay materias registradas aún."),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allCategories.length,
                      itemBuilder: (ctx, i) {
                        final cat = allCategories[i];
                        final isHidden = p.hiddenCategories.contains(cat);
                        return SwitchListTile(
                          title: Text(cat),
                          value: !isHidden, // Si NO está oculta, está activa
                          activeColor: const Color(0xFF6C63FF),
                          onChanged: (val) {
                            setModalState(() {
                              if (val) {
                                p.hiddenCategories.remove(cat);
                              } else {
                                p.hiddenCategories.add(cat);
                              }
                            });
                            p.save(); // Guardamos cambios en tiempo real
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _progressBox.listenable(),
      builder: (context, Box<UserProgress> box, _) {
        final p = box.getAt(0)!;
        final time = TimeOfDay(hour: p.notificationHour, minute: p.notificationMinute);
        final isDark = p.isDarkMode;

        return Scaffold(
          appBar: AppBar(title: const Text("Configuración")),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader("Personalización"),
              _buildCard(context, [
                _buildTile(
                  title: "Materias y Temas",
                  subtitle: "Elige qué quieres estudiar",
                  icon: Icons.filter_list_rounded,
                  color: Colors.blueAccent,
                  onTap: () => _showCategoryFilter(p),
                ),
                const Divider(height: 1, indent: 60),
                SwitchListTile(
                  title: const Text("Modo Oscuro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text(isDark ? "Activado 🌙" : "Desactivado ☀️", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: const Color(0xFF6C63FF), size: 24),
                  ),
                  value: isDark,
                  activeColor: const Color(0xFF6C63FF),
                  onChanged: (val) {
                    p.isDarkMode = val;
                    p.save();
                  },
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionHeader("Notificaciones"),
              _buildCard(context, [
                _buildTile(
                  title: "Recordatorio Diario",
                  subtitle: "Te avisaremos a las ${time.format(context)}",
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFFFFBC42),
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                  onTap: () => _pickTime(p),
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionHeader("Seguridad de Datos"),
              _buildCard(context, [
                _buildTile(
                  title: "Crear Respaldo",
                  subtitle: "Guarda todo tu progreso",
                  icon: Icons.cloud_upload_rounded,
                  color: const Color(0xFF4ECDC4),
                  onTap: _backupData,
                ),
                const Divider(height: 1, indent: 60),
                _buildTile(
                  title: "Restaurar Copia",
                  subtitle: "Recupera tus datos",
                  icon: Icons.cloud_download_rounded,
                  color: const Color(0xFF6C63FF),
                  onTap: _restoreData,
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  // Widgets auxiliares (iguales a antes)
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}