import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/question.dart';
import 'package:uuid/uuid.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  final _categoryController = TextEditingController();

  void _saveQuestion() async {
    final questionBox = Hive.box<Question>('questionsBox');
    final uuid = const Uuid();

    final newQuestion = Question(
      id: uuid.v4(),
      questionText: _questionController.text.trim(),
      options: _optionControllers.map((c) => c.text.trim()).toList(),
      correctAnswerIndex: _correctIndex,
      category: _categoryController.text.trim().isEmpty
          ? 'General'
          : _categoryController.text.trim(),
      createdAt: DateTime.now(),
    );

    await questionBox.add(newQuestion);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pregunta guardada ✅')),
    );

    _questionController.clear();
    for (var c in _optionControllers) {
      c.clear();
    }
    _categoryController.clear();
    setState(() {
      _correctIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Pregunta')),
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
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar pregunta'),
                onPressed: _saveQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
