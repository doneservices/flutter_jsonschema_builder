import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

JsonFormSchemaUiConfig buildDemoFileUiConfig() => JsonFormSchemaUiConfig(
  filesBuilder: (files, {required onRemove}) {
    if (files == null || files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final file in files)
            _DemoFilePreview(file: file, onRemove: onRemove),
        ],
      ),
    );
  },
);

Widget demoReviewFileBuilder(
  BuildContext context,
  SchemaProperty property,
  List<String> values,
) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final value in values)
      _DemoReviewFilePreview(value: value, isVideo: property.isVideo),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_jsonschema_builder demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

/// Demo schema covering the main field types and features: nested objects,
/// enums, booleans, dates, files (single + multi) and dependencies.
const demoJsonSchema = '''
{
  "title": "Field showcase",
  "description": "The main field types and features, one of each.",
  "type": "object",
  "properties": {
    "name": {
      "type": "object",
      "title": "About you",
      "description": "A nested object: a titled section in classic mode, a single step in stepped mode.",
      "required": ["firstName"],
      "properties": {
        "firstName": {"type": "string", "title": "First name", "minLength": 2},
        "lastName": {"type": "string", "title": "Last name"}
      }
    },
    "email": {"type": "string", "format": "email", "title": "Email"},
    "birthDate": {"type": "string", "format": "date", "title": "Birth date"},
    "age": {"type": "integer", "title": "Age", "minimum": 0},
    "favoriteColor": {
      "type": "string",
      "title": "Favorite color",
      "description": "Enum + enumNames: radio in stepped mode, dropdown in classic",
      "enum": ["red", "green", "blue"],
      "enumNames": ["Red", "Green", "Blue"]
    },
    "newsletter": {
      "type": "boolean",
      "title": "Subscribe to the newsletter",
      "description": "A boolean: rendered as a checkbox"
    },
    "pet": {
      "type": "string",
      "title": "Do you have a pet?",
      "description": "Selecting cat inserts a follow-up question (dependencies)",
      "enum": ["none", "cat"]
    },
    "street": {"type": "string", "title": "Street"},
    "city": {"type": "string", "title": "City"},
    "avatar": {
      "type": "string",
      "format": "data-url",
      "title": "Avatar",
      "description": "Single file with image preview"
    },
    "attachments": {
      "type": "array",
      "title": "Attachments",
      "description": "Multiple files via an array of data-urls",
      "items": {"type": "string", "format": "data-url"}
    },
    "video": {
      "type": "string",
      "format": "video",
      "title": "Video response",
      "description": "Choose an existing video or record one with the camera"
    }
  },
  "required": ["email", "favoriteColor", "newsletter", "avatar"],
  "dependencies": {
    "pet": {
      "oneOf": [
        {"properties": {"pet": {"enum": ["none"]}}},
        {
          "properties": {
            "pet": {"enum": ["cat"]},
            "petName": {"type": "string", "title": "Pet name"}
          }
        }
      ]
    }
  }
}
''';

/// Ui schema showing the main keys: ui:media (bundled assets and a custom
/// lottie type; rendered by the stepped mode only), ui:group for same-step
/// grouping without changing the data shape, and ui:order.
const demoUiSchema = '''
{
  "ui:order": [
    "name",
    "email",
    "birthDate",
    "age",
    "favoriteColor",
    "newsletter",
    "pet",
    "street",
    "city",
    "avatar",
    "attachments",
    "video"
  ],
  "name": {
    "ui:media": {"type": "asset", "src": "assets/gradient.png"}
  },
  "favoriteColor": {
    "ui:media": {"type": "lottie", "src": "assets/pulse.json", "height": 120}
  },
  "avatar": {
    "ui:options": {"filePreview": true, "fileType": "image"}
  },
  "attachments": {
    "ui:options": {"filePreview": true, "fileType": "image"}
  },
  "street": {"ui:group": "address"},
  "city": {"ui:group": "address"}
}
''';

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

Future<List<SchemaFormFile>?> _pickFiles(
  BuildContext context,
  SchemaProperty property,
) async {
  final isImage = property.fileType?.toLowerCase() == 'image';
  if (!isImage && !property.isVideo) return _pickFromFiles(property);

  final source = await _selectFileSource(context, isVideo: property.isVideo);
  if (source == null) return null;

  if (source == _FileSource.files) return _pickFromFiles(property);

  final imageSource =
      source == _FileSource.camera ? ImageSource.camera : ImageSource.gallery;
  final picker = ImagePicker();

  if (property.isVideo) {
    final video = await picker.pickVideo(source: imageSource);
    return _schemaFilesFromPickerResult(
      video == null ? const [] : [video],
      isVideo: true,
    );
  }

  final images =
      imageSource == ImageSource.gallery && property.isMultipleFile
          ? await picker.pickMultiImage()
          : [
            if (await picker.pickImage(source: imageSource) case final image?)
              image,
          ];
  return _schemaFilesFromPickerResult(images, isVideo: false);
}

Future<List<SchemaFormFile>?> _pickFromFiles(SchemaProperty property) async {
  final type =
      property.isVideo || property.fileType?.toLowerCase() == 'image'
          ? FileType.custom
          : FileType.any;
  final result = await FilePicker.pickFiles(
    type: type,
    allowedExtensions:
        type == FileType.custom
            ? property.isVideo
                ? const ['mp4', 'mov', 'm4v', 'webm', '3gp']
                : const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic']
            : null,
    withData: !property.isVideo || kIsWeb,
    allowMultiple: property.isMultipleFile,
  );
  final files = result?.files ?? [];
  if (files.isEmpty) return null;
  return files
      .where((file) => file.bytes != null || file.path != null)
      .map(
        (file) => SchemaFormFile(
          name: file.name,
          value:
              property.isVideo && file.path != null
                  ? file.path!
                  : Uri.dataFromBytes(
                    file.bytes ?? Uint8List(0),
                    mimeType: _mimeTypeFor(file.name),
                  ).toString(),
          bytes: file.bytes ?? Uint8List(0),
        ),
      )
      .toList();
}

Future<List<SchemaFormFile>?> _schemaFilesFromPickerResult(
  List<XFile> files, {
  required bool isVideo,
}) async {
  final result = await Future.wait(
    files.map((file) async {
      final bytes = isVideo ? Uint8List(0) : await file.readAsBytes();
      return SchemaFormFile(
        name: file.name,
        value:
            isVideo
                ? file.path
                : Uri.dataFromBytes(
                  bytes,
                  mimeType: _mimeTypeFor(file.name),
                ).toString(),
        bytes: bytes,
      );
    }),
  );
  return result.isEmpty ? null : result;
}

String _mimeTypeFor(String name) {
  const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'pdf': 'application/pdf',
  };
  final extension =
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return mimeTypes[extension] ?? 'application/octet-stream';
}

enum _FileSource { camera, library, files }

Future<_FileSource?> _selectFileSource(
  BuildContext context, {
  required bool isVideo,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<_FileSource>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isVideo ? Icons.videocam : Icons.add_a_photo),
                title: Text(isVideo ? 'Record video' : 'Take photo'),
                onTap: () => Navigator.pop(context, _FileSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo library'),
                onTap: () => Navigator.pop(context, _FileSource.library),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Files'),
                onTap: () => Navigator.pop(context, _FileSource.files),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
  );
}

class _DemoFilePreview extends StatelessWidget {
  const _DemoFilePreview({required this.file, required this.onRemove});

  final SchemaFormFile file;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final mimeType = _mimeTypeFor(file.name);
    final Widget preview =
        mimeType.startsWith('image/')
            ? Image.memory(
              file.bytes,
              key: const Key('demo-image-preview'),
              width: 140,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) => const _FileIcon(Icons.image),
            )
            : mimeType.startsWith('video/')
            ? _DemoVideoPreview(
              key: const Key('demo-video-preview'),
              value: file.value,
            )
            : const _FileIcon(Icons.insert_drive_file_outlined);

    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onRemove(file.value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _DemoVideoPreview extends StatefulWidget {
  const _DemoVideoPreview({super.key, required this.value});

  final String value;

  @override
  State<_DemoVideoPreview> createState() => _DemoVideoPreviewState();
}

class _DemoVideoPreviewState extends State<_DemoVideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final uri =
        widget.value.startsWith('data:')
            ? Uri.parse(widget.value)
            : Uri.file(widget.value);
    _controller = VideoPlayerController.networkUrl(uri);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Keep the video icon when a platform cannot preview this file.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = AspectRatio(
      aspectRatio:
          _ready && _controller.value.aspectRatio > 0
              ? _controller.value.aspectRatio
              : 16 / 9,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_ready)
              VideoPlayer(_controller)
            else
              const Icon(Icons.video_file),
            if (_ready)
              Icon(
                _controller.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                color: Colors.white,
                size: 36,
              ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap:
          !_ready
              ? null
              : () async {
                _controller.value.isPlaying
                    ? await _controller.pause()
                    : await _controller.play();
                if (mounted) setState(() {});
              },
      child: video,
    );
  }
}

class _DemoReviewFilePreview extends StatelessWidget {
  const _DemoReviewFilePreview({required this.value, required this.isVideo});

  final String value;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          key: const Key('demo-review-video-preview'),
          constraints: const BoxConstraints(maxWidth: 64, maxHeight: 64),
          child: _DemoVideoPreview(value: value),
        ),
      );
    }

    Uint8List? bytes;
    try {
      bytes = Uri.parse(value).data?.contentAsBytes();
    } catch (_) {}

    return ConstrainedBox(
      key: const Key('demo-review-image-preview'),
      constraints: const BoxConstraints(maxWidth: 64, maxHeight: 64),
      child:
          bytes == null
              ? const _FileIcon(Icons.image, size: 64)
              : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const _FileIcon(Icons.image, size: 64),
                ),
              ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon(this.icon, {this.size = 140});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 9 / 14,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, size: 40),
    ),
  );
}

class _DemoHomePageState extends State<DemoHomePage> {
  JsonFormDisplayMode _displayMode = JsonFormDisplayMode.stepped;
  Axis _transitionAxis = Axis.vertical;
  bool _showReviewStep = true;

  @override
  Widget build(BuildContext context) {
    final isStepped = _displayMode == JsonFormDisplayMode.stepped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON Schema Form'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected:
                (value) => setState(() {
                  switch (value) {
                    case 'mode':
                      _displayMode =
                          isStepped
                              ? JsonFormDisplayMode.fullForm
                              : JsonFormDisplayMode.stepped;
                      break;
                    case 'axis':
                      _transitionAxis =
                          _transitionAxis == Axis.vertical
                              ? Axis.horizontal
                              : Axis.vertical;
                      break;
                    case 'review':
                      _showReviewStep = !_showReviewStep;
                      break;
                  }
                }),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'mode',
                    child: Text(
                      isStepped
                          ? 'Switch to classic'
                          : 'Switch to step by step',
                    ),
                  ),
                  if (isStepped) ...[
                    PopupMenuItem(
                      value: 'axis',
                      child: Text(
                        'Transition: ${_transitionAxis == Axis.vertical ? 'vertical' : 'horizontal'}',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'review',
                      child: Text(
                        'Review step: ${_showReviewStep ? 'on' : 'off'}',
                      ),
                    ),
                  ],
                ],
          ),
        ],
      ),
      body: isStepped ? _buildSteppedForm() : _buildClassicForm(),
    );
  }

  Widget _buildSteppedForm() {
    // Key forces a fresh form when the knobs change, so toggles apply cleanly.
    return JsonForm(
      key: ValueKey('stepped-$_transitionAxis-$_showReviewStep'),
      jsonSchema: demoJsonSchema,
      uiSchema: demoUiSchema,
      showDebugElements: false,
      fileHandler: () => {'*': (property) => _pickFiles(context, property)},
      jsonFormSchemaUiConfig: buildDemoFileUiConfig(),
      displayMode: JsonFormDisplayMode.stepped,
      steppedConfig: JsonFormSteppedConfig(
        transitionAxis: _transitionAxis,
        showReviewStep: _showReviewStep,
        reviewDescription: 'Tap an answer to change it.',
        reviewFileBuilder: demoReviewFileBuilder,
        mediaBuilder: (context, media) {
          if (media.type == 'lottie') {
            return Lottie.asset(media.src, height: media.height ?? 160);
          }
          return null;
        },
      ),
      onFormDataSaved: _showResult,
    );
  }

  Widget _buildClassicForm() {
    return SingleChildScrollView(
      child: JsonForm(
        jsonSchema: demoJsonSchema,
        uiSchema: demoUiSchema,
        showDebugElements: false,
        fileHandler: () => {'*': (property) => _pickFiles(context, property)},
        jsonFormSchemaUiConfig: buildDemoFileUiConfig(),
        onFormDataSaved: _showResult,
      ),
    );
  }

  void _showResult(dynamic data) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Form data'),
            content: SingleChildScrollView(
              child: Text(const JsonEncoder.withIndent('  ').convert(data)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
