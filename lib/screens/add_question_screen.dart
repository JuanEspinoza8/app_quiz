import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../models/question.dart';
import 'package:uuid/uuid.dart';

class AddQuestionScreen extends StatefulWidget {
  final Question? editQuestion; // si viene con valor, estamos editando

  const AddQuestionScreen({super.key, this.editQuestion});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  final _categoryController = TextEditingController();

  // 👇 Nueva parte para manejar imágenes
  File? _selectedImage;
  final _picker = ImagePicker();

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
    // Si estamos editando, llenamos los campos
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

      // 👇 Si tiene imagen guardada, la cargamos
      if (q.imagePath != null) {
        _selectedImage = File(q.imagePath!);
      }
    }
  }

  void _saveQuestion() async {
    final questionBox = Hive.box<Question>('questionsBox');
    final uuid = const Uuid();

    // Crear objeto con datos actuales
    final newOrUpdated = Question(
      id: widget.editQuestion?.id ?? uuid.v4(),
      questionText: _questionController.text.trim(),
      options: _optionControllers.map((c) => c.text.trim()).toList(),
      correctAnswerIndex: _correctIndex,
      category: _categoryController.text.trim().isEmpty
          ? 'General'
          : _categoryController.text.trim(),
      createdAt:
      widget.editQuestion?.createdAt ?? DateTime.now(), // conserva fecha
      imagePath: _selectedImage?.path, // 👈 guardamos ruta de imagen
    );

    // Guardar o actualizar
    if (widget.editQuestion != null) {
      final index = questionBox.values.toList().indexOf(widget.editQuestion!);
      if (index != -1) {
        await questionBox.putAt(index, newOrUpdated);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pregunta actualizada ✅')),
      );
    } else {
      await questionBox.add(newOrUpdated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pregunta guardada ✅')),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editQuestion == null
            ? 'Agregar Pregunta'
            : 'Editar Pregunta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enunciado de la pregunta'),
            TextField(controller: _questionController),
            const SizedBox(height: 16),
            const Text('Opciones (respuestas posibles):'),
            for (int i = 0; i < 4; i++)
              ListTile(
                title: TextField(
                  controller: _optionControllers[i],
                  decoration: InputDecoration(labelText: 'Opción ${i + 1}'),
                ),
                leading: Radio<int>(
                  value: i,
                  groupValue: _correctIndex,
                  onChanged: (val) => setState(() => _correctIndex = val!),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Categoría o tema'),
            TextField(controller: _categoryController),

            const SizedBox(height: 24),
            const Text('Imagen opcional:'),
            const SizedBox(height: 8),
            if (_selectedImage != null)
              Center(
                child: Image.file(
                  _selectedImage!,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Seleccionar imagen'),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(widget.editQuestion == null
                    ? 'Guardar pregunta'
                    : 'Actualizar pregunta'),
                onPressed: _saveQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
