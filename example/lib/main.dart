import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:lottie/lottie.dart';

import 'demo_file_handling.dart';

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
      "description": "Choose your **favorite color** — there is *no wrong answer*.\\n\\n- **Red** for a warm look\\n- **Green** for a natural feel\\n- **Blue** for a calm mood\\n\\nExplore [color palettes](https://m3.material.io/styles/color/overview).",
      "enum": ["red", "green", "blue"],
      "enumNames": ["Red", "Green", "Blue"]
    },
    "formExperience": {
      "type": "string",
      "title": "How was this form?",
      "enum": ["Easy", "Okay", "Hard"]
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
      "format": "data-url",
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
/// grouping without changing the data shape, ui:widget for a custom field,
/// and ui:order.
const demoUiSchema = '''
{
  "ui:order": [
    "name",
    "email",
    "birthDate",
    "age",
    "favoriteColor",
    "formExperience",
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
  "formExperience": {"ui:widget": "choiceChips"},
  "avatar": {
    "ui:options": {"filePreview": true, "fileType": "image"}
  },
  "attachments": {
    "ui:options": {"filePreview": true, "fileType": "image"}
  },
  "video": {
    "ui:options": {"filePreview": true, "fileType": "video", "accept": ".mp4,.mov,.m4v"}
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
      fieldBuilders: {'choiceChips': _buildChoiceChips},
      showDebugElements: false,
      fileHandler: () => {'*': (property) => pickDemoFiles(context, property)},
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
      onLinkTap: (_, href, _) => _openLink(context, href),
      onFormDataSaved: _showResult,
    );
  }

  Widget _buildClassicForm() {
    return SingleChildScrollView(
      child: JsonForm(
        jsonSchema: demoJsonSchema,
        uiSchema: demoUiSchema,
        fieldBuilders: {'choiceChips': _buildChoiceChips},
        showDebugElements: false,
        fileHandler:
            () => {'*': (property) => pickDemoFiles(context, property)},
        jsonFormSchemaUiConfig: buildDemoFileUiConfig(),
        onLinkTap: (_, href, _) => _openLink(context, href),
        onFormDataSaved: _showResult,
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri != null &&
        const ['https', 'http', 'mailto', 'tel', 'sms'].contains(uri.scheme)) {
      try {
        if (await launchUrl(uri)) return;
      } on PlatformException catch (_) {
        // Show the same feedback as when no application can handle the link.
      } on MissingPluginException catch (_) {
        // A plugin added during development needs a fresh app run.
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
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

Widget _buildChoiceChips(
  BuildContext context,
  SchemaProperty property,
  dynamic value,
  String? errorText,
  ValueChanged<dynamic> onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(property.title),
      Wrap(
        spacing: 8,
        children: [
          for (final choice in property.enumm!.cast<String>())
            ChoiceChip(
              label: Text(choice),
              selected: value == choice,
              onSelected:
                  property.disabled == true || property.readOnly
                      ? null
                      : (selected) => onChanged(selected ? choice : null),
            ),
        ],
      ),
      if (errorText != null)
        Text(
          errorText,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
