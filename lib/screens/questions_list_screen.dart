import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/question.dart';

class QuestionsListScreen extends StatelessWidget {
  const QuestionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Question>('questions');

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
                title: Text(question.questionText),
                subtitle: Text('Categoría: ${question.category}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => box.deleteAt(index),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
