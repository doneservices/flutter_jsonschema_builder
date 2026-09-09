import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Demo-only adapter between the form's file callbacks and platform pickers.
///
/// Applications decide where files come from and what [SchemaFormFile.value]
/// stores. This demo keeps images as data URLs and videos as local paths; a
/// production app would commonly upload the bytes and store the remote key.
Future<List<SchemaFormFile>?> pickDemoFiles(
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
