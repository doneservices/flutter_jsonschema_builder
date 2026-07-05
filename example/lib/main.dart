import 'dart:convert';

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

/// A plain JSON schema that works in both display modes: the nested `name`
/// object renders as a titled section in classic mode and becomes a single
/// step (with the same title and description) in stepped mode.
const demoJsonSchema = '''
{
  "title": "Tell us about you",
  "type": "object",
  "required": ["email", "topic"],
  "properties": {
    "name": {
      "type": "object",
      "title": "What should we call you?",
      "description": "First things first — introduce yourself.",
      "required": ["first"],
      "properties": {
        "first": {"type": "string", "title": "First name"},
        "last": {"type": "string", "title": "Last name"}
      }
    },
    "email": {"type": "string", "title": "Email", "format": "email", "minLength": 5},
    "topic": {
      "type": "string",
      "title": "What brings you here?",
      "enum": ["work", "hobby", "school"],
      "enumNames": ["Work", "Hobby", "School"]
    },
    "excitement": {
      "type": "integer",
      "title": "How excited are you?",
      "description": "1 = meh, 5 = can't wait",
      "enum": [1, 2, 3, 4, 5],
      "enumNames": ["1", "2", "3", "4", "5"]
    },
    "comments": {"type": "string", "title": "Anything else?"}
  }
}
''';

/// The only step-specific ui schema addition is `ui:media`, which attaches
/// an image or animation to a field's or object's step.
const demoUiSchema = '''
{
  "name": {
    "ui:media": {"type": "lottie", "src": "assets/pulse.json", "height": 160}
  },
  "email": {
    "ui:media": {"type": "asset", "src": "assets/gradient.png", "height": 150, "fit": "cover"}
  },
  "topic": {"ui:widget": "radio"},
  "excitement": {
    "ui:media": {"type": "lottie", "src": "assets/pulse.json", "height": 120}
  }
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
          if (isStepped)
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune),
              onSelected: (value) => setState(() {
                switch (value) {
                  case 'axis':
                    _transitionAxis = _transitionAxis == Axis.vertical
                        ? Axis.horizontal
                        : Axis.vertical;
                    break;
                  case 'review':
                    _showReviewStep = !_showReviewStep;
                    break;
                }
              }),
              itemBuilder: (context) => [
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
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<JsonFormDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: JsonFormDisplayMode.stepped,
                  label: Text('Step by step'),
                  icon: Icon(Icons.linear_scale),
                ),
                ButtonSegment(
                  value: JsonFormDisplayMode.fullForm,
                  label: Text('Classic'),
                  icon: Icon(Icons.list_alt),
                ),
              ],
              selected: {_displayMode},
              onSelectionChanged: (selection) =>
                  setState(() => _displayMode = selection.first),
            ),
          ),
          Expanded(
            child: isStepped ? _buildSteppedForm() : _buildClassicForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSteppedForm() {
    // Key forces a fresh form when the knobs change, so toggles apply cleanly.
    return JsonForm(
      key: ValueKey('stepped-$_transitionAxis-$_showReviewStep'),
      jsonSchema: demoJsonSchema,
      uiSchema: demoUiSchema,
      showDebugElements: false,
      displayMode: JsonFormDisplayMode.stepped,
      steppedConfig: JsonFormSteppedConfig(
        transitionAxis: _transitionAxis,
        showReviewStep: _showReviewStep,
        reviewDescription: 'Tap an answer to change it.',
        // The package has no Lottie dependency: the app decides how custom
        // media types render. Returning null falls back to the built-in
        // handling of the `image`/`asset` types.
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
        onFormDataSaved: _showResult,
      ),
    );
  }

  void _showResult(dynamic data) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
