import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:lottie/lottie.dart';

void main() {
  runApp(const MyApp());
}

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
    "attachments"
  ],
  "name": {
    "ui:media": {"type": "asset", "src": "assets/gradient.png", "height": 120}
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

/// Default file handler for every `data-url` field: opens the platform file
/// picker and encodes the result as a data URL, matching the schema format.
Future<List<SchemaFormFile>?> _pickFiles(SchemaProperty property) async {
  final result = await FilePicker.pickFiles(
    withData: true,
    allowMultiple: property.isMultipleFile,
  );
  final files = result?.files ?? [];
  if (files.isEmpty) return null;
  // ponytail: covers the formats this demo realistically picks; use
  // package:mime if an app needs full coverage
  const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'pdf': 'application/pdf',
  };
  return files
      .where((f) => f.bytes != null)
      .map(
        (f) => SchemaFormFile(
          name: f.name,
          value:
              Uri.dataFromBytes(
                f.bytes!,
                mimeType:
                    mimeTypes[f.extension?.toLowerCase()] ??
                    'application/octet-stream',
              ).toString(),
          bytes: f.bytes!,
        ),
      )
      .toList();
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
      fileHandler: () => {'*': _pickFiles},
      displayMode: JsonFormDisplayMode.stepped,
      steppedConfig: JsonFormSteppedConfig(
        transitionAxis: _transitionAxis,
        showReviewStep: _showReviewStep,
        reviewDescription: 'Tap an answer to change it.',
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
        fileHandler: () => {'*': _pickFiles},
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
