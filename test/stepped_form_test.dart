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

void main() {
  group('extractJsonFormSteps', () {
    test(
        'a plain schema needs no ui schema: scalars get their own step, '
        'a nested object becomes one step titled by its schema', () {
      final steps = extractJsonFormSteps(parseSchema(testJsonSchema));

      expect(steps.length, 3);
      expect(steps.map((s) => s.id), ['name', 'age', 'bio']);
      expect(steps.first.entries.map((e) => e.schema.id), ['first', 'last']);
      expect(steps.first.title, 'What is your name?');
      expect(steps.first.description, 'So we know what to call you');
      expect(steps[1].entries.single.schema.id, 'age');
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
        'ui:step optionally groups flat siblings onto one step '
        'without changing the data shape', () {
      const flatSchema = '''
      {
        "type": "object",
        "properties": {
          "firstName": {"type": "string"},
          "lastName": {"type": "string"},
          "age": {"type": "integer"}
        }
      }
      ''';
      const flatUiSchema = '''
      {
        "firstName": {"ui:step": "name"},
        "lastName": {"ui:step": "name"}
      }
      ''';

      final steps = extractJsonFormSteps(
          parseSchema(flatSchema, uiSchema: flatUiSchema));

      expect(steps.length, 2);
      expect(steps.first.id, 'step-group:name');
      expect(steps.first.entries.map((e) => e.schema.id),
          ['firstName', 'lastName']);
      expect(steps[1].entries.single.schema.id, 'age');
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
      expect(find.text('Back'), findsNothing);
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
      expect(find.text('Back'), findsOneWidget);

      await tester.tap(find.text('Back'));
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
