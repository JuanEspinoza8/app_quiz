import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../models/question.dart';

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
  int _correctIndex = 0;
  File? _selectedImage;
  List<String> _existingCategories = [];

  @override
  void initState() {
    super.initState();
    final box = Hive.box<Question>('questionsBox');
    _existingCategories = box.values.map((q) => q.category).toSet().toList();

    if (widget.editQuestion != null) {
      final q = widget.editQuestion!;
      _questionController.text = q.questionText;
      for (int i = 0; i < 4; i++) if (i < q.options.length) _optionControllers[i].text = q.options[i];
      _correctIndex = q.correctAnswerIndex;
      _categoryController.text = q.category;
      _explanationController.text = q.explanation ?? '';
      if (q.imagePath != null) _selectedImage = File(q.imagePath!);
    }
  }

  void _save() {
    if (_questionController.text.isEmpty || _categoryController.text.isEmpty) return;
    final box = Hive.box<Question>('questionsBox');
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
    );
    if (widget.editQuestion != null) {
      final idx = box.values.toList().indexOf(widget.editQuestion!);
      if (idx != -1) box.putAt(idx, q);
    } else {
      box.add(q);
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
                        Autocomplete<String>(
                          optionsBuilder: (v) => _existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                          onSelected: (val) => _categoryController.text = val,
                          fieldViewBuilder: (c, ctrl, n, _) {
                            if (_categoryController.text.isNotEmpty && ctrl.text.isEmpty) ctrl.text = _categoryController.text;
                            ctrl.addListener(() => _categoryController.text = ctrl.text);
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
                      if(p!=null) setState(() => _selectedImage = File(p.path));
                    },
                    child: Container(
                      height: 80, width: 80,
                      margin: const EdgeInsets.only(top: 24),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1), // ✅ Neutro
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
            ...List.generate(4, (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Theme.of(context).cardColor, // ✅ Dinámico
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _correctIndex == i ? const Color(0xFF4ECDC4) : Colors.transparent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
              ),
              child: RadioListTile<int>(
                value: i, groupValue: _correctIndex, onChanged: (v) => setState(() => _correctIndex = v!),
                activeColor: const Color(0xFF4ECDC4),
                title: TextField(
                    controller: _optionControllers[i],
                    decoration: InputDecoration(hintText: 'Opción ${i+1}', border: InputBorder.none),
                    style: const TextStyle(fontSize: 14)
                ),
              ),
            )),

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
                  backgroundColor: const Color(0xFF6C63FF),
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
          color: Theme.of(context).cardColor, // ✅ Dinámico
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1), // ✅ Neutro y suave
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16)
    );
  }
}