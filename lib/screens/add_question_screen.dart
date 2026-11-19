import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/question_repository.dart';
import '../logic/question_validator.dart';
import '../models/question.dart';
import '../services/image_store.dart';
import '../theme/app_colors.dart';
import '../widgets/question_image.dart';

/// Elige una imagen y devuelve su ruta (o null si se canceló).
typedef ImagePathPicker = Future<String?> Function();

Future<String?> _pickFromGallery() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  return picked?.path;
}

class AddQuestionScreen extends StatefulWidget {
  final Question? editQuestion;

  /// Para los tests; por defecto abre la galería.
  final ImagePathPicker? pickImage;

  const AddQuestionScreen({super.key, this.editQuestion, this.pickImage});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

/// Una fila del editor de relacionar: el texto de la izquierda y su imagen.
class _PairDraft {
  final TextEditingController text;
  String? imageRef;
  _PairDraft({String text = '', this.imageRef}) : text = TextEditingController(text: text);
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _categoryController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  List<String> _existingCategories = [];
  late String _type;
  bool _saving = false;

  /// Lo que falta para poder guardar. Se muestra arriba del botón y no en un
  /// SnackBar, que lo taparía justo cuando se lo quiere volver a tocar.
  String? _error;

  // Opción múltiple
  final List<TextEditingController> _optionControllers = [];
  int _correctIndex = 0;
  String? _imageRef;

  // Relacionar
  final List<_PairDraft> _pairs = [];

  bool get _isEditing => widget.editQuestion != null;

  @override
  void initState() {
    super.initState();
    _existingCategories = context.read<QuestionRepository>().categories;

    final q = widget.editQuestion;
    _type = q?.type ?? QuestionType.multipleChoice;
    if (q != null) {
      _questionController.text = q.questionText;
      _categoryController.text = q.category;
      _explanationController.text = q.explanation ?? '';
      _imageRef = q.imagePath;
      _correctIndex = q.correctAnswerIndex;
      for (final option in q.options) {
        _optionControllers.add(TextEditingController(text: option));
      }
      for (var i = 0; i < q.matchLeft.length; i++) {
        _pairs.add(_PairDraft(text: q.matchLeft[i], imageRef: i < q.matchImages.length ? q.matchImages[i] : null));
      }
    }

    // Lugares vacíos para empezar: 4 opciones y 3 parejas, como el ejemplo
    // típico. Al editar se respeta lo que tenía la pregunta.
    final minOptions = q == null ? 4 : kMinOptions;
    while (_optionControllers.length < minOptions) {
      _optionControllers.add(TextEditingController());
    }
    final minPairs = q == null ? 3 : kMinPairs;
    while (_pairs.length < minPairs) {
      _pairs.add(_PairDraft());
    }
    if (_correctIndex < 0 || _correctIndex >= _optionControllers.length) _correctIndex = 0;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final p in _pairs) {
      p.text.dispose();
    }
    super.dispose();
  }

  /// Elige una imagen y la copia a la carpeta de la app: la ruta que devuelve
  /// image_picker está en la caché y el sistema la puede borrar.
  Future<String?> _pickImage() async {
    final images = context.read<ImageStore>();
    final path = await (widget.pickImage ?? _pickFromGallery)();
    if (path == null) return null;
    try {
      return await images.saveFromPath(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar la imagen: $e')));
      }
      return null;
    }
  }

  void _addOption() => setState(() => _optionControllers.add(TextEditingController()));

  void _removeOption(int index) {
    setState(() {
      _optionControllers.removeAt(index).dispose();
      if (_correctIndex == index) {
        _correctIndex = 0;
      } else if (_correctIndex > index) {
        _correctIndex--;
      }
    });
  }

  void _addPair() => setState(() => _pairs.add(_PairDraft()));

  void _removePair(int index) => setState(() => _pairs.removeAt(index).text.dispose());

  Question _buildQuestion() {
    final original = widget.editQuestion;
    final repo = context.read<QuestionRepository>();
    final explanation = _explanationController.text.trim();
    final isMatching = _type == QuestionType.matching;

    return Question(
      id: original?.id ?? const Uuid().v4(),
      type: _type,
      questionText: _questionController.text.trim(),
      options: isMatching ? const [] : [for (final c in _optionControllers) c.text.trim()],
      correctAnswerIndex: isMatching ? 0 : _correctIndex,
      category: repo.canonicalCategory(_categoryController.text),
      createdAt: original?.createdAt ?? DateTime.now(),
      imagePath: isMatching ? null : _imageRef,
      explanation: explanation.isEmpty ? null : explanation,
      errorCount: original?.errorCount ?? 0,
      totalAttempts: original?.totalAttempts ?? 0,
      correctCount: original?.correctCount ?? 0,
      matchLeft: isMatching ? [for (final p in _pairs) p.text.text.trim()] : const [],
      matchImages: isMatching ? [for (final p in _pairs) p.imageRef ?? ''] : const [],
    );
  }

  Future<void> _save() async {
    final repo = context.read<QuestionRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final question = _buildQuestion();

    final error = validateQuestion(question);
    setState(() {
      _error = error;
      _saving = error == null;
    });
    if (error != null) return;

    try {
      final original = widget.editQuestion;
      if (original != null) {
        await repo.update(original, question);
      } else {
        await repo.add(question);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar la pregunta: $e')));
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMatching = _type == QuestionType.matching;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar Pregunta' : 'Nueva Pregunta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: QuestionType.multipleChoice, label: Text('Opción múltiple'), icon: Icon(Icons.list_alt)),
                ButtonSegment(value: QuestionType.matching, label: Text('Relacionar'), icon: Icon(Icons.link)),
              ],
              selected: {_type},
              // Al editar no se cambia el tipo: las respuestas guardadas no servirían.
              onSelectionChanged: _isEditing ? null : (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 20),
            _buildCard([
              _label('Enunciado'),
              TextField(
                key: const ValueKey('question-text'),
                controller: _questionController,
                maxLines: 2,
                decoration: _inputDeco(isMatching ? 'Uní cada número con su imagen' : '¿Cuál es la capital de...'),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Categoría'),
                        // Autocomplete usa directamente nuestro controller: no hace
                        // falta copiar el texto con un listener en cada build.
                        Autocomplete<String>(
                          textEditingController: _categoryController,
                          focusNode: _categoryFocusNode,
                          optionsBuilder: (v) => _existingCategories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
                          fieldViewBuilder: (c, ctrl, n, _) {
                            return TextField(
                              key: const ValueKey('category'),
                              controller: ctrl,
                              focusNode: n,
                              decoration: _inputDeco('Historia...'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!isMatching) ...[
                    const SizedBox(width: 16),
                    _ImageSlot(
                      key: const ValueKey('question-image'),
                      imageRef: _imageRef,
                      size: 80,
                      onPick: () async {
                        final ref = await _pickImage();
                        if (ref != null && mounted) setState(() => _imageRef = ref);
                      },
                      onClear: () => setState(() => _imageRef = null),
                      clearTooltip: 'Quitar imagen',
                    ),
                  ],
                ],
              ),
            ]),
            const SizedBox(height: 20),
            if (isMatching) ..._buildPairs() else ..._buildOptions(),
            const SizedBox(height: 20),
            _buildCard([
              _label('Explicación (Opcional)'),
              TextField(controller: _explanationController, maxLines: 2, decoration: _inputDeco('Aparecerá al responder...')),
            ]),
            const SizedBox(height: 30),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.pink.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.pink),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("GUARDAR PREGUNTA", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    return [
      _sectionTitle("Opciones (marcá la correcta)"),
      RadioGroup<int>(
        groupValue: _correctIndex,
        onChanged: (v) => setState(() => _correctIndex = v!),
        child: Column(
          children: [
            for (var i = 0; i < _optionControllers.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _correctIndex == i ? AppColors.teal : Colors.transparent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                ),
                // Material transparente para que el efecto de toque se vea
                // por encima del fondo del Container.
                child: Material(
                  type: MaterialType.transparency,
                  child: RadioListTile<int>(
                    value: i,
                    activeColor: AppColors.teal,
                    title: TextField(
                      key: ValueKey('option-$i'),
                      controller: _optionControllers[i],
                      decoration: InputDecoration(hintText: 'Opción ${i + 1}', border: InputBorder.none),
                      style: const TextStyle(fontSize: 14),
                    ),
                    secondary: _optionControllers.length > kMinOptions
                        ? IconButton(
                            tooltip: 'Quitar opción ${i + 1}',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _removeOption(i),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (_optionControllers.length < kMaxOptions)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add), label: const Text('Agregar opción')),
        ),
    ];
  }

  List<Widget> _buildPairs() {
    return [
      _sectionTitle('Parejas'),
      Text(
        'Cada fila es una pareja correcta: el texto de la izquierda va con la imagen de su derecha. '
        'Al jugar, las imágenes aparecen mezcladas.',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _pairs.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('pair-text-$i'),
                  controller: _pairs[i].text,
                  decoration: _inputDeco('Elemento ${i + 1}'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.grey),
              ),
              _ImageSlot(
                key: ValueKey('pair-image-$i'),
                imageRef: _pairs[i].imageRef,
                size: 72,
                onPick: () async {
                  final pair = _pairs[i];
                  final ref = await _pickImage();
                  if (ref != null && mounted) setState(() => pair.imageRef = ref);
                },
                onClear: () => setState(() => _pairs[i].imageRef = null),
                clearTooltip: 'Quitar imagen de la pareja ${i + 1}',
              ),
              if (_pairs.length > kMinPairs)
                IconButton(
                  tooltip: 'Quitar pareja ${i + 1}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removePair(i),
                ),
            ],
          ),
        ),
      if (_pairs.length < kMaxPairs)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _addPair, icon: const Icon(Icons.add), label: const Text('Agregar pareja')),
        ),
    ];
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey[600])),
      );

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(16));
  }
}

/// Cuadro para elegir una imagen, con un botón para quitarla.
class _ImageSlot extends StatelessWidget {
  final String? imageRef;
  final double size;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String clearTooltip;

  const _ImageSlot({
    super.key,
    required this.imageRef,
    required this.size,
    required this.onPick,
    required this.onClear,
    required this.clearTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPick,
                child: imageRef == null
                    ? const Tooltip(message: 'Elegir imagen', child: Icon(Icons.add_a_photo, color: Colors.grey))
                    : QuestionImage(imageRef: imageRef, width: size, height: size),
              ),
            ),
          ),
          if (imageRef != null)
            Positioned(
              top: -10,
              right: -10,
              child: IconButton.filledTonal(
                tooltip: clearTooltip,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
            ),
        ],
      ),
    );
  }
}
