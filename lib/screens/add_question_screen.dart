import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/question_repository.dart';
import '../models/question.dart';
import '../theme/app_colors.dart';

class AddQuestionScreen extends StatefulWidget {
  final Question? editQuestion;
  const AddQuestionScreen({super.key, this.editQuestion});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  final _explanationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  int _correctIndex = 0;
  File? _selectedImage;
  List<String> _existingCategories = [];

  @override
  void initState() {
    super.initState();
    _existingCategories = context.read<QuestionRepository>().categories;

    if (widget.editQuestion != null) {
      final q = widget.editQuestion!;
      _questionController.text = q.questionText;
      for (int i = 0; i < 4 && i < q.options.length; i++) {
        _optionControllers[i].text = q.options[i];
      }
      _correctIndex = q.correctAnswerIndex;
      _categoryController.text = q.category;
      _explanationController.text = q.explanation ?? '';
      if (q.imagePath != null) _selectedImage = File(q.imagePath!);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _explanationController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    if (_questionController.text.isEmpty || _categoryController.text.isEmpty) return;
    final repo = context.read<QuestionRepository>();
    final q = Question(
      id: widget.editQuestion?.id ?? const Uuid().v4(),
      questionText: _questionController.text.trim(),
      options: _optionControllers.map((c) => c.text.trim()).toList(),
      correctAnswerIndex: _correctIndex,
      category: _categoryController.text.trim(),
      createdAt: widget.editQuestion?.createdAt ?? DateTime.now(),
      imagePath: _selectedImage?.path,
      explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
      errorCount: widget.editQuestion?.errorCount ?? 0,
      totalAttempts: widget.editQuestion?.totalAttempts ?? 0,
      correctCount: widget.editQuestion?.correctCount ?? 0,
    );
    if (widget.editQuestion != null) {
      repo.update(widget.editQuestion!, q);
    } else {
      repo.add(q);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editQuestion == null ? 'Nueva Pregunta' : 'Editar Pregunta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard([
              Text("Enunciado", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _questionController, maxLines: 2,
                decoration: _inputDeco('¿Cuál es la capital de...'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Categoría", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // Autocomplete usa directamente nuestro controller: no hace
                        // falta copiar el texto con un listener en cada build.
                        Autocomplete<String>(
                          textEditingController: _categoryController,
                          focusNode: _categoryFocusNode,
                          optionsBuilder: (v) => _existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                          fieldViewBuilder: (c, ctrl, n, _) {
                            return TextField(controller: ctrl, focusNode: n, decoration: _inputDeco('Historia...'));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () async {
                      final p = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (p != null && mounted) setState(() => _selectedImage = File(p.path));
                    },
                    child: Container(
                      height: 80, width: 80,
                      margin: const EdgeInsets.only(top: 24),
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          image: _selectedImage != null ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover) : null
                      ),
                      child: _selectedImage == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                    ),
                  )
                ],
              )
            ]),

            const SizedBox(height: 20),

            Text("Opciones (Marca la correcta)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 10),
            RadioGroup<int>(
              groupValue: _correctIndex,
              onChanged: (v) => setState(() => _correctIndex = v!),
              child: Column(
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _correctIndex == i ? AppColors.teal : Colors.transparent, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]
                  ),
                  // Material transparente para que el efecto de toque se vea
                  // por encima del fondo del Container.
                  child: Material(
                    type: MaterialType.transparency,
                    child: RadioListTile<int>(
                      value: i,
                      activeColor: AppColors.teal,
                      title: TextField(
                          controller: _optionControllers[i],
                          decoration: InputDecoration(hintText: 'Opción ${i+1}', border: InputBorder.none),
                          style: const TextStyle(fontSize: 14)
                      ),
                    ),
                  ),
                )),
              ),
            ),

            const SizedBox(height: 20),
            _buildCard([
              Text("Explicación (Opcional)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: _explanationController, maxLines: 2, decoration: _inputDeco('Aparecerá al responder...')),
            ]),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              child: const Text("GUARDAR PREGUNTA", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16)
    );
  }
}