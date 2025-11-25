import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../models/question.dart';
import 'package:uuid/uuid.dart';

class AddQuestionScreen extends StatefulWidget {
  final Question? editQuestion;

  const AddQuestionScreen({super.key, this.editQuestion});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  // Controlador para explicación
  final _explanationController = TextEditingController();

  // Controlador para categoría (lo usaremos con el Autocomplete)
  final _categoryController = TextEditingController();

  File? _selectedImage;
  final _picker = ImagePicker();

  // Lista de categorías existentes para sugerir
  List<String> _existingCategories = [];

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.editQuestion != null) {
      final q = widget.editQuestion!;
      _questionController.text = q.questionText;
      for (int i = 0; i < _optionControllers.length; i++) {
        if (i < q.options.length) {
          _optionControllers[i].text = q.options[i];
        }
      }
      _correctIndex = q.correctAnswerIndex;
      _categoryController.text = q.category;
      _explanationController.text = q.explanation ?? '';

      if (q.imagePath != null) {
        _selectedImage = File(q.imagePath!);
      }
    }
  }

  void _loadCategories() {
    final box = Hive.box<Question>('questionsBox');
    final categories = box.values.map((q) => q.category).toSet().toList();
    setState(() {
      _existingCategories = categories;
    });
  }

  void _saveQuestion() async {
    final questionBox = Hive.box<Question>('questionsBox');
    final uuid = const Uuid();

    // Validaciones básicas
    if (_questionController.text.isEmpty || _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faltan datos obligatorios ⚠️')));
      return;
    }

    final newOrUpdated = Question(
      id: widget.editQuestion?.id ?? uuid.v4(),
      questionText: _questionController.text.trim(),
      options: _optionControllers.map((c) => c.text.trim()).toList(),
      correctAnswerIndex: _correctIndex,
      category: _categoryController.text.trim(),
      createdAt: widget.editQuestion?.createdAt ?? DateTime.now(),
      imagePath: _selectedImage?.path,
      // Guardamos la explicación y mantenemos estadísticas viejas si editamos
      explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
      errorCount: widget.editQuestion?.errorCount ?? 0,
      totalAttempts: widget.editQuestion?.totalAttempts ?? 0,
    );

    if (widget.editQuestion != null) {
      final index = questionBox.values.toList().indexOf(widget.editQuestion!);
      if (index != -1) {
        await questionBox.putAt(index, newOrUpdated);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta actualizada ✅')));
    } else {
      await questionBox.add(newOrUpdated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pregunta guardada ✅')));
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editQuestion == null ? 'Agregar Pregunta' : 'Editar Pregunta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enunciado', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(hintText: 'Ej: ¿Cuál es la capital de Francia?'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            const Text('Opciones', style: TextStyle(fontWeight: FontWeight.bold)),
            for (int i = 0; i < 4; i++)
              RadioListTile<int>(
                title: TextField(
                  controller: _optionControllers[i],
                  decoration: InputDecoration(hintText: 'Opción ${i + 1}'),
                ),
                value: i,
                groupValue: _correctIndex,
                onChanged: (val) => setState(() => _correctIndex = val!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: 16),
            const Text('Explicación (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Aparecerá después de responder para aclarar dudas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
              controller: _explanationController,
              decoration: const InputDecoration(hintText: 'Ej: París es la capital desde el año...'),
              maxLines: 2,
            ),

            const SizedBox(height: 16),
            const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
            // 👇 Autocomplete Mágico
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return _existingCategories.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _categoryController.text = selection;
              },
              fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
                // Sincronizamos el controlador interno del Autocomplete con el nuestro si es necesario
                if (_categoryController.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                  fieldTextEditingController.text = _categoryController.text;
                }
                // Escuchamos cambios manuales
                fieldTextEditingController.addListener(() {
                  _categoryController.text = fieldTextEditingController.text;
                });

                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Historia, Matemáticas...',
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                if (_selectedImage != null)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.file(_selectedImage!, width: 80, height: 80, fit: BoxFit.cover),
                      InkWell(
                        onTap: () => setState(() => _selectedImage = null),
                        child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                      )
                    ],
                  ),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Imagen (Opcional)'),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('GUARDAR'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}