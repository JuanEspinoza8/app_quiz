import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _attachedFileName;
  Uint8List? _attachedFileBytes;
  String? _attachedMimeType;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<Question>('questionsBox');
    _existingCategories = box.values.map((q) => q.category).toSet().toList();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'], withData: true);
    if (result != null) {
      final file = result.files.single;
      setState(() {
        _attachedFileName = file.name;
        _attachedFileBytes = file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);
        final ext = file.extension?.toLowerCase();
        if (ext == 'pdf') _attachedMimeType = 'application/pdf';
        else if (ext == 'png') _attachedMimeType = 'image/png';
        else if (ext == 'jpg' || ext == 'jpeg') _attachedMimeType = 'image/jpeg';
      });
    }
  }

  Future<void> _generate({bool append = false}) async {
    if (_textController.text.trim().isEmpty && _attachedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe texto o adjunta archivo 📂')));
      return;
    }
    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta la categoría 🏷️')));
      return;
    }

    setState(() => _isLoading = true);
    final avoidList = append ? _generatedQuestions.map((q) => q.questionText).toList() : <String>[];

    try {
      final newQuestions = await GeminiService.generateQuestions(
        _textController.text,
        userCategory: _categoryController.text.trim(),
        avoidQuestions: avoidList,
        fileBytes: _attachedFileBytes,
        mimeType: _attachedMimeType,
      );
      setState(() {
        if (append) _generatedQuestions.addAll(newQuestions);
        else _generatedQuestions = newQuestions;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editQuestionLocal(int index) {
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
            title: const Text("Editar"),
            content: SingleChildScrollView(
              child: Column(children: [
                TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: "Pregunta")),
                const SizedBox(height: 10),
                ...List.generate(4, (i) => Row(children: [Radio<int>(value: i, groupValue: tempCorrectIndex, onChanged: (v)=>setDialogState(()=>tempCorrectIndex=v!)), Expanded(child: TextField(controller: optionCtrls[i]))])),
                TextField(controller: explanationCtrl, decoration: const InputDecoration(labelText: "Explicación")),
              ]),
            ),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () {
                setState(() => _generatedQuestions[index] = Question(id: q.id, questionText: questionCtrl.text, options: optionCtrls.map((c)=>c.text).toList(), correctAnswerIndex: tempCorrectIndex, category: _categoryController.text, createdAt: q.createdAt, explanation: explanationCtrl.text, errorCount: 0, totalAttempts: 0));
                Navigator.pop(context);
              }, child: const Text("Guardar"))
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAll() async {
    final box = Hive.box<Question>('questionsBox');
    for (var q in _generatedQuestions) await box.add(q);
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado ✅'))); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar con IA ✨')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Theme.of(context).cardColor, // ✅ Dinámico
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("1. Categoría", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Autocomplete<String>(
                          optionsBuilder: (v) => _existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                          onSelected: (val) => _categoryController.text = val,
                          fieldViewBuilder: (context, controller, node, _) {
                            if (_categoryController.text.isNotEmpty && controller.text.isEmpty) controller.text = _categoryController.text;
                            controller.addListener(() => _categoryController.text = controller.text);
                            return TextField(
                              controller: controller, focusNode: node,
                              decoration: InputDecoration(
                                  hintText: 'Ej: Biología...',
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.1), // ✅ Neutro
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("2. Contenido", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            TextButton.icon(onPressed: _pickFile, icon: const Icon(Icons.attach_file, size: 18), label: const Text("Adjuntar PDF/Img"))
                          ],
                        ),
                        if (_attachedFileName != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20), const SizedBox(width: 8), Expanded(child: Text(_attachedFileName!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple), overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() { _attachedFileName=null; _attachedFileBytes=null; }), icon: const Icon(Icons.close, size: 18))]),
                          ),
                        TextField(
                          controller: _textController,
                          maxLines: 5,
                          decoration: InputDecoration(
                              hintText: 'Pega aquí tus apuntes...',
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.1), // ✅ Neutro
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: () => _generate(append: _generatedQuestions.isNotEmpty),
                      icon: Icon(_generatedQuestions.isEmpty ? Icons.auto_awesome : Icons.add),
                      label: Text(_generatedQuestions.isEmpty ? 'Generar Preguntas' : 'Generar +5 Más'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _generatedQuestions.isEmpty ? const Color(0xFF6C63FF) : const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),

                  if (_generatedQuestions.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Vista Previa (${_generatedQuestions.length})", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () => setState(() => _generatedQuestions.clear()), child: const Text("Limpiar", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                    ..._generatedQuestions.asMap().entries.map((entry) {
                      final i = entry.key; final q = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: Theme.of(context).cardColor, // ✅ Dinámico
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), child: Text("${i+1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                          title: Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Resp: ${q.options[q.correctAnswerIndex]}", style: TextStyle(color: Colors.grey[600])),
                          trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
                          onTap: () => _editQuestionLocal(i),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveAll,
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text("GUARDAR TODO"),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}