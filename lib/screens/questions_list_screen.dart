import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/question.dart';
import 'add_question_screen.dart'; // 👈 necesario para poder editar
import 'dart:io';


class QuestionsListScreen extends StatelessWidget {
  const QuestionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Question>('questionsBox');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preguntas guardadas'),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Question> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No hay preguntas aún 💤'));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final question = box.getAt(index)!;

              return ListTile(
                leading: question.imagePath != null
                    ? Image.file(
                  File(question.imagePath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
                    : const Icon(Icons.image_not_supported),

                title: Text(question.questionText),
                subtitle: Text('Categoría: ${question.category}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, box, index),
                ),
                // 👇 si tocás la pregunta, la abre para editarla
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddQuestionScreen(editQuestion: question),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Función auxiliar para confirmar antes de borrar
void _confirmDelete(BuildContext context, Box<Question> box, int index) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar pregunta'),
      content: const Text('¿Seguro que querés borrar esta pregunta?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    box.deleteAt(index);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pregunta eliminada ✅')),
    );
  }
}
