import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart'; // 👈 Necesario
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/gemini_service.dart';
import '../models/question.dart';

class AiGeneratorScreen extends StatefulWidget {
  const AiGeneratorScreen({super.key});

  @override
  State<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends State<AiGeneratorScreen> {
  final _textController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _isLoading = false;
  List<Question> _generatedQuestions = [];
  List<String> _existingCategories = [];

  // Variables para el archivo adjunto
  String? _attachedFileName;
  Uint8List? _attachedFileBytes;
  String? _attachedMimeType;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final box = Hive.box<Question>('questionsBox');
    final cats = box.values.map((q) => q.category).toSet().toList();
    setState(() {
      _existingCategories = cats;
    });
  }

  // 👇 Función para adjuntar archivo
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'], // Tipos soportados por Gemini Flash
      withData: true, // Importante para tener los bytes en memoria
    );

    if (result != null) {
      final file = result.files.single;
      setState(() {
        _attachedFileName = file.name;
        _attachedFileBytes = file.bytes; // Si es web o desktop. En móvil a veces es null y se lee del path.

        // Parche para móviles si bytes es null
        if (_attachedFileBytes == null && file.path != null) {
          _attachedFileBytes = File(file.path!).readAsBytesSync();
        }

        // Detectar MimeType básico
        final ext = file.extension?.toLowerCase();
        if (ext == 'pdf') _attachedMimeType = 'application/pdf';
        else if (ext == 'png') _attachedMimeType = 'image/png';
        else if (ext == 'jpg' || ext == 'jpeg') _attachedMimeType = 'image/jpeg';
      });
    }
  }

  void _removeFile() {
    setState(() {
      _attachedFileName = null;
      _attachedFileBytes = null;
      _attachedMimeType = null;
    });
  }

  Future<void> _generate({bool append = false}) async {
    // Validaciones: Debe haber texto O archivo
    if (_textController.text.trim().isEmpty && _attachedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un texto O adjunta un archivo 📂')));
      return;
    }
    // Si es solo texto, pedimos un mínimo de longitud. Si hay archivo, no importa.
    if (_attachedFileBytes == null && _textController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El texto es muy corto (mínimo 50 letras) ✍️')));
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor escribe o selecciona una categoría 🏷️')));
      return;
    }

    setState(() => _isLoading = true);

    final avoidList = append ? _generatedQuestions.map((q) => q.questionText).toList() : <String>[];

    try {
      final newQuestions = await GeminiService.generateQuestions(
        _textController.text, // Puede estar vacío si hay archivo
        userCategory: _categoryController.text.trim(),
        avoidQuestions: avoidList,
        fileBytes: _attachedFileBytes,
        mimeType: _attachedMimeType,
      );

      setState(() {
        if (append) {
          _generatedQuestions.addAll(newQuestions);
        } else {
          _generatedQuestions = newQuestions;
        }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editQuestion(int index) {
    final q = _generatedQuestions[index];
    final questionCtrl = TextEditingController(text: q.questionText);
    final explanationCtrl = TextEditingController(text: q.explanation);
    final optionCtrls = List.generate(4, (i) => TextEditingController(text: q.options[i]));
    int tempCorrectIndex = q.correctAnswerIndex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Editar Pregunta"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: "Enunciado"), maxLines: 2),
                  const SizedBox(height: 10),
                  const Text("Opciones:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(4, (i) => Row(children: [
                    Radio<int>(value: i, groupValue: tempCorrectIndex, onChanged: (val) => setDialogState(() => tempCorrectIndex = val!)),
                    Expanded(child: TextField(controller: optionCtrls[i], decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.all(8)))),
                  ])),
                  const SizedBox(height: 10),
                  TextField(controller: explanationCtrl, decoration: const InputDecoration(labelText: "Explicación"), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _generatedQuestions[index] = Question(
                      id: q.id,
                      questionText: questionCtrl.text,
                      options: optionCtrls.map((c) => c.text).toList(),
                      correctAnswerIndex: tempCorrectIndex,
                      category: _categoryController.text,
                      createdAt: q.createdAt,
                      explanation: explanationCtrl.text,
                      errorCount: 0, totalAttempts: 0,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text("Guardar"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_generatedQuestions.isEmpty) return;
    final box = Hive.box<Question>('questionsBox');
    for (var q in _generatedQuestions) await box.add(q);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡${_generatedQuestions.length} preguntas guardadas! 🎉')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar con IA 🤖')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AVISO
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text("Soporta texto, PDF e imágenes.", style: TextStyle(fontSize: 12, color: Colors.blue))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("1. Elige la categoría:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Autocomplete<String>(
                      optionsBuilder: (v) => v.text.isEmpty ? const Iterable.empty() : _existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                      onSelected: (val) => _categoryController.text = val,
                      fieldViewBuilder: (context, controller, node, onSubmitted) {
                        if (_categoryController.text.isNotEmpty && controller.text.isEmpty) controller.text = _categoryController.text;
                        controller.addListener(() => _categoryController.text = controller.text);
                        return TextField(controller: controller, focusNode: node, decoration: const InputDecoration(hintText: 'Ej: Biología...', border: OutlineInputBorder()));
                      },
                    ),
                    const SizedBox(height: 16),

                    // ÁREA DE TEXTO + ADJUNTO
                    const Text("2. Fuente (Texto o Archivo):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Pega texto aquí...',
                        border: const OutlineInputBorder(),
                        // Botón dentro del input para adjuntar
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.attach_file),
                          onPressed: _pickFile,
                          tooltip: "Adjuntar PDF o Imagen",
                        ),
                      ),
                    ),

                    // PREVIEW DEL ARCHIVO ADJUNTO
                    if (_attachedFileName != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400)
                        ),
                        child: Row(
                          children: [
                            Icon(_attachedMimeType == 'application/pdf' ? Icons.picture_as_pdf : Icons.image, color: Colors.deepPurple),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_attachedFileName!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: _removeFile,
                            )
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                    // LÓGICA DE BOTONES DINÁMICA
                      _generatedQuestions.isEmpty
                          ? SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _generate(append: false),
                          icon: const Icon(Icons.flash_on),
                          label: const Text('Generar (5)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      )
                          : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _generate(append: true),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Generar +5 más (sin borrar)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade100, foregroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_generatedQuestions.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Preguntas (${_generatedQuestions.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => setState(() => _generatedQuestions.clear()), child: const Text("Limpiar todo")),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _generatedQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _generatedQuestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _editQuestion(index),
                        title: Text(q.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text("Resp: ${q.options[q.correctAnswerIndex]}"),
                        leading: CircleAvatar(child: Text("${index + 1}")),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => setState(() => _generatedQuestions.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAll,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("GUARDAR TODO EN MI BIBLIOTECA"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}