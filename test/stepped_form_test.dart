import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// a plain JSON schema — grouping comes from the nested `name` object,
/// its step header from the object's own title/description
const testJsonSchema = '''
{
  "title": "Onboarding",
  "type": "object",
  "properties": {
    "name": {
      "type": "object",
      "title": "What is your name?",
      "description": "So we know what to call you",
      "required": ["first"],
      "properties": {
        "first": {"type": "string", "title": "First name"},
        "last": {"type": "string", "title": "Last name"}
      }
    },
    "age": {"type": "integer", "title": "Age"},
    "bio": {"type": "string", "title": "Bio"}
  }
}
''';

/// a `dependencies`/`oneOf` trigger that inserts a `petName` field when
/// "cat" is selected — in stepped mode that means inserting/removing a
/// whole step mid-flow
const dependencyJsonSchema = '''
{
  "title": "Onboarding",
  "type": "object",
  "properties": {
    "pet": {"type": "string", "title": "Do you have a pet?", "enum": ["none", "cat"]},
    "bio": {"type": "string", "title": "Bio"}
  },
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

/// enums render as radio lists in stepped mode — select by tapping the label
Future<void> selectRadioValue(WidgetTester tester, String value) async {
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

/// media is the only step-specific ui schema addition
const testUiSchema = '''
{
  "name": {"ui:media": {"type": "custom-animation", "src": "hello.json"}},
  "age": {"ui:media": {"type": "image", "src": "https://example.com/age.png"}}
}
''';

SchemaObject parseSchema(String jsonSchema, {String? uiSchema}) {
  return (Schema.fromJson(json.decode(jsonSchema), id: kGenesisIdKey)
      as SchemaObject)
    ..setUiSchema(uiSchema != null ? json.decode(uiSchema) : null);
}

Widget buildTestApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> flushTextDebounce(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

/// the text field currently holding focus — i.e. the one the software
/// keyboard would be attached to — or null when the keyboard is dismissed
EditableText? focusedTextField(WidgetTester tester) {
  for (final editable in tester.widgetList<EditableText>(
      find.byType(EditableText, skipOffstage: false))) {
    if (editable.focusNode.hasFocus) return editable;
  }
  return null;
}

void main() {
  group('extractJsonFormSteps', () {
    test(
        'a plain schema needs no ui schema: scalars get their own step, '
        'a nested object becomes one step titled by its schema', () {
      final steps = extractJsonFormSteps(parseSchema(testJsonSchema));

      expect(steps.length, 3);
      expect(steps.map((s) => s.id), ['name', 'age', 'bio']);
      expect(steps.first.schemas.map((s) => s.id), ['first', 'last']);
      expect(steps.first.title, 'What is your name?');
      expect(steps.first.description, 'So we know what to call you');
      expect(steps.first.parent.id, 'name');
      expect(steps[1].schemas.single.id, 'age');
      expect(steps[1].parent.id, kGenesisIdKey);
    });

    test('ui:media on an object or field attaches media to its step', () {
      final steps = extractJsonFormSteps(
          parseSchema(testJsonSchema, uiSchema: testUiSchema));

      expect(steps.first.media?.type, 'custom-animation');
      expect(steps.first.media?.src, 'hello.json');
      expect(steps[1].media?.type, 'image');
      expect(steps[1].media?.src, 'https://example.com/age.png');
      expect(steps[2].media, isNull);
    });

    test(
        'ui:group merges flat fields onto one step at the first member\'s '
        'position, with the first media carried by a member', () {
      const uiSchema = '''
      {
        "age": {"ui:group": "personal"},
        "bio": {
          "ui:group": "personal",
          "ui:media": {"type": "image", "src": "https://example.com/p.png"}
        }
      }
      ''';
      final steps =
          extractJsonFormSteps(parseSchema(testJsonSchema, uiSchema: uiSchema));

      expect(steps.length, 2);
      expect(steps[1].id, 'group:personal');
      expect(steps[1].schemas.map((s) => s.id), ['age', 'bio']);
      expect(steps[1].parent.id, kGenesisIdKey);
      expect(steps[1].media?.src, 'https://example.com/p.png');
    });

    test('duplicate property ids still produce unique step ids', () {
      final schema = parseSchema(testJsonSchema);
      final age = schema.properties!.firstWhere((p) => p.id == 'age');
      schema.properties!.add(age.copyWith(id: 'age'));

      final steps = extractJsonFormSteps(schema);

      expect(steps.map((s) => s.id).toSet().length, steps.length);
    });
  });

  group('ui schema scoping and hardening', () {
    test('object-level ui keys apply to the object, not its children', () {
      const uiSchema = '''
      {
        "name": {
          "ui:title": "Custom section",
          "ui:media": {"type": "image", "src": "x.png"}
        }
      }
      ''';
      final schema = parseSchema(testJsonSchema, uiSchema: uiSchema);
      final name = schema.properties!.first as SchemaObject;

      expect(name.title, 'Custom section');
      expect(name.uiMedia?.src, 'x.png');

      final first = name.properties!.first as SchemaProperty;
      expect(first.title, 'First name');
      expect(first.uiMedia, isNull);
    });

    test('partial nested ui:order keeps unlisted fields after listed ones',
        () {
      const uiSchema = '{"ui:order": ["bio"], "name": {"ui:order": ["last"]}}';
      final schema = parseSchema(testJsonSchema, uiSchema: uiSchema);

      // multiple unlisted ids keep their relative schema order
      expect(schema.properties!.map((p) => p.id), ['bio', 'name', 'age']);

      final name =
          schema.properties!.whereType<SchemaObject>().first;
      expect(name.properties!.map((p) => p.id), ['last', 'first']);
    });

    test('malformed ui:media entries are ignored instead of crashing', () {
      const uiSchema = '''
      {
        "age": {"ui:media": "not-a-map"},
        "bio": {"ui:media": {"type": "image", "src": "a.png", "height": "120"}}
      }
      ''';
      final schema = parseSchema(testJsonSchema, uiSchema: uiSchema);
      final age = schema.properties!.firstWhere((p) => p.id == 'age');
      final bio = schema.properties!.firstWhere((p) => p.id == 'bio');

      expect(age.uiMedia, isNull);
      expect(bio.uiMedia?.height, 120.0);
    });
  });

  group('stepped display mode', () {
    testWidgets(
        'shows one step at a time with the object title as header '
        'and a progress counter', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      // header comes straight from the nested object's schema title
      expect(find.text('What is your name?'), findsOneWidget);
      expect(find.text('So we know what to call you'), findsOneWidget);
      expect(find.textContaining('First name'), findsOneWidget);
      expect(find.textContaining('Last name'), findsOneWidget);
      expect(find.textContaining('Age'), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      // no back button on the first step
      expect(find.text('Previous'), findsNothing);
    });

    testWidgets('validation blocks advancing past a required field',
        (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // still on step 1, error shown
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets(
        'valid step advances, custom media builder renders custom types, '
        'and back navigation preserves state', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        uiSchema: testUiSchema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig: JsonFormSteppedConfig(
          mediaBuilder: (context, media) => media.type == 'image'
              ? Container(
                  key: const Key('custom-image-media'),
                  height: media.height ?? 100,
                )
              : null,
        ),
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await flushTextDebounce(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // second step: age, with the media handled by the custom builder
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining('Age'), findsOneWidget);
      expect(find.byKey(const Key('custom-image-media')), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();

      // the text entered on step 1 survived the round trip
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets(
        'last step submits data shaped like the schema structure',
        (tester) async {
      dynamic savedData;
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (data) => savedData = data,
      )));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await tester.enterText(find.byKey(const Key('name.last')), 'Lovelace');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('age')), '36');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // last step shows Submit instead of Next
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      await tester.enterText(find.byKey(const Key('bio')), 'First programmer');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(savedData, isNotNull);
      // nested in the data exactly as nested in the schema
      expect(savedData['name']['first'], 'Ada');
      expect(savedData['name']['last'], 'Lovelace');
      // the number field stores its raw text value, as in fullForm mode
      expect(savedData['age'], '36');
      expect(savedData['bio'], 'First programmer');
    });

    testWidgets('review step renders file answers as icons, not data urls',
        (tester) async {
      const schema = '''
      {
        "type": "object",
        "properties": {
          "photo": {"type": "string", "format": "data-url", "title": "Photo"},
          "bio": {"type": "string", "title": "Bio"}
        }
      }
      ''';
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: schema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig: const JsonFormSteppedConfig(showReviewStep: true),
        fileHandler: () => {'*': (_) async => null},
        initialData: const {'photo': 'data:image/png;base64,AAAA'},
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // review page: an icon for the file, never the raw data url
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.textContaining('base64'), findsNothing);
    });

    testWidgets('review step lists answers and jumps back on tap',
        (tester) async {
      dynamic savedData;
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig: const JsonFormSteppedConfig(showReviewStep: true),
        onFormDataSaved: (data) => savedData = data,
      )));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // review page is counted as a page of its own
      expect(find.text('4 / 4'), findsOneWidget);
      expect(find.text('Review your answers'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);

      // jump back to the first step by tapping its answer
      await tester.tap(find.textContaining('First name'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 4'), findsOneWidget);

      // walk forward again and submit from the review page
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(savedData, isNotNull);
      expect(savedData['name']['first'], 'Ada');
    });

    testWidgets(
        'a dependency-inserted step joins the flow, leaves it again, '
        'and submits its data', (tester) async {
      dynamic savedData;
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: dependencyJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        // auto-advance off: this test stays on the trigger step to watch
        // the dependent step come and go
        steppedConfig:
            const JsonFormSteppedConfig(autoAdvanceOnSelect: false),
        onFormDataSaved: (data) => savedData = data,
      )));
      await tester.pump();

      expect(find.text('1 / 2'), findsOneWidget);

      // selecting the trigger value inserts the dependent step...
      await selectRadioValue(tester, 'cat');
      expect(find.text('1 / 3'), findsOneWidget);

      // ...and selecting the other value removes it again
      await selectRadioValue(tester, 'none');
      expect(find.text('1 / 2'), findsOneWidget);

      await selectRadioValue(tester, 'cat');
      expect(find.text('1 / 3'), findsOneWidget);

      // the inserted step comes right after its trigger and is navigable
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining('Pet name'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('petName')), 'Whiskers');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('3 / 3'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bio')), 'Cat person');
      await flushTextDebounce(tester);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(savedData, isNotNull);
      expect(savedData['pet'], 'cat');
      expect(savedData['petName'], 'Whiskers');
      expect(savedData['bio'], 'Cat person');
    });

    testWidgets(
        'selecting an enum value auto-advances a single-field step '
        'but not a grouped one', (tester) async {
      const schema = '''
      {
        "type": "object",
        "properties": {
          "pet": {"type": "string", "title": "Pet?", "enum": ["none", "cat"]},
          "color": {"type": "string", "title": "Color?", "enum": ["red", "blue"]},
          "bio": {"type": "string", "title": "Bio"}
        }
      }
      ''';
      const uiSchema = '''
      {
        "color": {"ui:group": "extra"},
        "bio": {"ui:group": "extra"}
      }
      ''';
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: schema,
        uiSchema: uiSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      expect(find.text('1 / 2'), findsOneWidget);
      await selectRadioValue(tester, 'cat');
      // single-field step: the selection advanced the page
      expect(find.text('2 / 2'), findsOneWidget);

      // grouped step: selecting does not advance
      await selectRadioValue(tester, 'blue');
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets(
        'the keyboard action button moves to the next text field on the '
        'page, then to the next page', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      // step 1 holds two text fields (first, last)
      await tester.showKeyboard(find.byKey(const Key('name.first')));
      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(focusedTextField(tester), isNotNull);

      // enter on the page's last text field advances the page
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('a double-tap on Next advances a single step', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await flushTextDebounce(tester);

      // the second tap lands mid-transition and must be ignored
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('a double-tap on Submit fires onSubmit once', (tester) async {
      var submitCount = 0;
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: dependencyJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) => submitCount++,
      )));
      await tester.pump();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Submit'), findsOneWidget);

      // both taps arrive before the consumer gets a frame to react
      await tester.tap(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(submitCount, 1);
    });

    testWidgets('navigation controls float over the page content',
        (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      // the Next button overlays the page area instead of stacking below
      // it, so the page keeps the full height (crucial with a keyboard up)
      final pageRect = tester.getRect(find.byType(PageView));
      final nextRect =
          tester.getRect(find.widgetWithText(ElevatedButton, 'Next'));
      expect(nextRect.top, greaterThanOrEqualTo(pageRect.top));
      expect(nextRect.bottom, lessThanOrEqualTo(pageRect.bottom));
    });

    testWidgets(
        'scroll clearance follows the measured height of custom controls',
        (tester) async {
      const tallControls = 160.0;
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig: JsonFormSteppedConfig(
          nextButtonBuilder: (onNext) => SizedBox(
            height: tallControls,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Next'),
            ),
          ),
        ),
        onFormDataSaved: (_) {},
      )));
      await tester.pump(); // first frame schedules the measurement
      await tester.pump(); // measured clearance applied

      // the page reserves at least the controls' height, so the last
      // field can always scroll clear of the floating buttons
      final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first);
      expect(
        scroll.padding!.resolve(TextDirection.ltr).bottom,
        greaterThanOrEqualTo(tallControls),
      );
    });

    testWidgets(
        'keyboard focus follows navigation into the next text field and '
        'drops on the review page', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig: const JsonFormSteppedConfig(showReviewStep: true),
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      // typing gives step 1's field focus, as the software keyboard would
      await tester.enterText(find.byKey(const Key('name.first')), 'Ada');
      await flushTextDebounce(tester);
      expect(focusedTextField(tester), isNotNull);

      // the next steps have text fields too: focus moves along
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        focusedTextField(tester),
        tester.widget<EditableText>(find.descendant(
            of: find.byKey(const Key('age')),
            matching: find.byType(EditableText))),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        focusedTextField(tester),
        tester.widget<EditableText>(find.descendant(
            of: find.byKey(const Key('bio')),
            matching: find.byType(EditableText))),
      );

      // the review page takes no text input: the keyboard dismisses
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(focusedTextField(tester), isNull);
    });

    testWidgets(
        'keyboard dismisses on steps without text input and stays down '
        'when it was not up', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: dependencyJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      // nothing was focused: advancing must not pop the keyboard even
      // though the bio step has a text field
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bio'), findsOneWidget);
      expect(focusedTextField(tester), isNull);

      // typing on bio, then going back to the dropdown step: no text
      // input there, so focus drops and the keyboard dismisses
      await tester.enterText(find.byKey(const Key('bio')), 'Cat person');
      await flushTextDebounce(tester);
      expect(focusedTextField(tester), isNotNull);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(focusedTextField(tester), isNull);
    });

    testWidgets('horizontal transition axis is honored', (tester) async {
      await tester.pumpWidget(buildTestApp(JsonForm(
        jsonSchema: testJsonSchema,
        displayMode: JsonFormDisplayMode.stepped,
        steppedConfig:
            const JsonFormSteppedConfig(transitionAxis: Axis.horizontal),
        onFormDataSaved: (_) {},
      )));
      await tester.pump();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.scrollDirection, Axis.horizontal);
    });
  });
}
