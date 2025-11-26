import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_progress.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  int _dailyGoal = 5;

  void _finish() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Por favor dinos tu nombre! 🙏")));
      return;
    }

    final box = Hive.box<UserProgress>('progressBox');
    final p = box.getAt(0)!;

    p.userName = _nameController.text.trim();
    p.dailyGoal = _dailyGoal;
    p.save();

    // Vamos al Home y quitamos esta pantalla del historial
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        // 👇 AGREGADO: SingleChildScrollView permite deslizar si sale el teclado
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20), // Un poco de aire arriba
              const Icon(Icons.waving_hand_rounded, size: 60, color: Color(0xFF6C63FF)),
              const SizedBox(height: 20),
              Text(
                "¡Bienvenido!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Antes de empezar, configuremos tu perfil.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Nombre
              Text("¿Cómo te llamas?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Tu nombre...",
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 30),

              // Meta
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Preguntas diarias", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Text("$_dailyGoal", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), fontSize: 18)),
                ],
              ),
              Slider(
                value: _dailyGoal.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (v) => setState(() => _dailyGoal = v.toInt()),
              ),

              // 👇 CAMBIO: Quitamos Spacer() y ponemos un espacio fijo grande
              // para que el botón baje pero no rompa el scroll.
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: const Text("Comenzar Aventura 🚀", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),

              // Un espacio extra abajo por si acaso
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}