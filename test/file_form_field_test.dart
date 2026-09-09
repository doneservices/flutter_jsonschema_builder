import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video formats are file fields and support video UI options', () {
    final video = SchemaProperty.fromJson('video', {
      'type': 'string',
      'format': 'video',
    });
    final legacyVideo = SchemaProperty.fromJson('legacyVideo', {
      'type': 'string',
      'format': 'data-url',
    });
    legacyVideo.setUi({
      'ui:options': {'fileType': 'video', 'accept': 'video/mp4'},
    });

    expect(video.isFile, isTrue);
    expect(video.isVideo, isTrue);
    expect(legacyVideo.isFile, isTrue);
    expect(legacyVideo.isVideo, isTrue);
  });

  testWidgets('video fields use the standard file handler', (tester) async {
    dynamic latestData;

    await tester.pumpWidget(
      _TestApp(
        form: JsonForm(
          jsonSchema: json.encode(_schemaWithVideo),
          initialData: const <String, dynamic>{},
          onChanged: (data) => latestData = Map<String, dynamic>.from(data),
          onFormDataSaved: (_) {},
          fileHandler: () => {
            'video': (_) async => [
              SchemaFormFile(
                name: 'selected.mp4',
                value: 'stored-selected.mp4',
                bytes: Uint8List(0),
              ),
            ],
            '*': (_) async => const [],
          },
        ),
      ),
    );

    expect(find.text('Record video'), findsNothing);

    await tester.tap(find.text('Add File').last);
    await tester.pumpAndSettle();

    expect(latestData, {'video': 'stored-selected.mp4'});
    expect(find.text('selected.mp4'), findsOneWidget);
  });

  testWidgets('multiple file field appends new selections', (tester) async {
    var pickCount = 0;
    dynamic latestData;
    dynamic savedData;
    final initialData = <String, dynamic>{};

    await tester.pumpWidget(
      _TestApp(
        form: JsonForm(
          jsonSchema: json.encode(_schemaWithMultipleFiles),
          initialData: initialData,
          onChanged: (data) => latestData = Map<String, dynamic>.from(data),
          onFormDataSaved: (data) {
            savedData = Map<String, dynamic>.from(data as Map);
          },
          fileHandler: () => {
            '*': (_) async {
              pickCount++;
              return [
                SchemaFormFile(
                  name: 'file-$pickCount.jpg',
                  value: 'stored-file-$pickCount.jpg',
                  bytes: Uint8List(0),
                ),
              ];
            },
          },
          jsonFormSchemaUiConfig: JsonFormSchemaUiConfig(
            addFileButtonBuilder: (onPressed, _) {
              return ElevatedButton(
                onPressed: onPressed,
                child: const Text('Add file'),
              );
            },
            submitButtonBuilder: (onSubmit) {
              return ElevatedButton(
                onPressed: onSubmit,
                child: const Text('Submit'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add file'));
    await tester.pumpAndSettle();

    expect(latestData, {
      'files': ['stored-file-1.jpg'],
    });
    expect(find.text('file-1.jpg'), findsOneWidget);

    await tester.tap(find.text('Add file'));
    await tester.pumpAndSettle();

    expect(latestData, {
      'files': ['stored-file-1.jpg', 'stored-file-2.jpg'],
    });
    expect(find.text('file-1.jpg'), findsOneWidget);
    expect(find.text('file-2.jpg'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(savedData, {
      'files': ['stored-file-1.jpg', 'stored-file-2.jpg'],
    });
  });

  testWidgets('file handler completing after the field is disposed '
      'does not crash', (tester) async {
    final pickCompleter = Completer<List<SchemaFormFile>?>();

    await tester.pumpWidget(
      _TestApp(
        form: JsonForm(
          jsonSchema: json.encode(_schemaWithMultipleFiles),
          initialData: const <String, dynamic>{},
          onFormDataSaved: (_) {},
          fileHandler: () => {'*': (_) => pickCompleter.future},
          jsonFormSchemaUiConfig: JsonFormSchemaUiConfig(
            addFileButtonBuilder: (onPressed, _) {
              return ElevatedButton(
                onPressed: onPressed,
                child: const Text('Add file'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add file'));
    await tester.pump();

    // Dispose the form while the pick/upload is still in flight.
    await tester.pumpWidget(const _TestApp(form: SizedBox.shrink()));

    pickCompleter.complete([
      SchemaFormFile(
        name: 'late-file.jpg',
        value: 'stored-late-file.jpg',
        bytes: Uint8List(0),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('initial value handler completing after the field is disposed '
      'does not crash', (tester) async {
    final hydrateCompleter = Completer<List<SchemaFormFile>?>();

    await tester.pumpWidget(
      _TestApp(
        form: JsonForm(
          jsonSchema: json.encode(_schemaWithMultipleFiles),
          initialData: const <String, dynamic>{
            'files': <String>['stored-file-1.jpg'],
          },
          onFormDataSaved: (_) {},
          fileHandler: () => {'*': (_) async => const []},
          initialFileValueHandler: () => {'*': (_) => hydrateCompleter.future},
          jsonFormSchemaUiConfig: JsonFormSchemaUiConfig(
            addFileButtonBuilder: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();

    // Dispose the form while the initial download is still in flight.
    await tester.pumpWidget(const _TestApp(form: SizedBox.shrink()));

    hydrateCompleter.complete([
      SchemaFormFile(
        name: 'stored-file-1.jpg',
        value: 'stored-file-1.jpg',
        bytes: Uint8List(0),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple file field hydrates array initial data', (
    tester,
  ) async {
    dynamic handlerValue;
    List<SchemaFormFile>? renderedFiles;
    final initialData = <String, dynamic>{
      'files': <String>['stored-file-1.jpg', 'stored-file-2.jpg'],
    };

    await tester.pumpWidget(
      _TestApp(
        form: JsonForm(
          jsonSchema: json.encode(_schemaWithMultipleFiles),
          initialData: initialData,
          onFormDataSaved: (_) {},
          fileHandler: () => {'*': (_) async => const []},
          initialFileValueHandler: () => {
            '*': (value) async {
              handlerValue = value;
              return (value as List)
                  .cast<String>()
                  .map(
                    (file) => SchemaFormFile(
                      name: file,
                      value: file,
                      bytes: Uint8List(0),
                    ),
                  )
                  .toList();
            },
          },
          jsonFormSchemaUiConfig: JsonFormSchemaUiConfig(
            addFileButtonBuilder: (_, __) => const SizedBox.shrink(),
            filesBuilder: (files, {required onRemove}) {
              renderedFiles = files;
              return Column(
                children: [
                  for (final file in files ?? <SchemaFormFile>[])
                    Text(file.name),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(handlerValue, ['stored-file-1.jpg', 'stored-file-2.jpg']);
    expect(renderedFiles?.map((file) => file.value), [
      'stored-file-1.jpg',
      'stored-file-2.jpg',
    ]);
    expect(find.text('stored-file-1.jpg'), findsOneWidget);
    expect(find.text('stored-file-2.jpg'), findsOneWidget);
  });
}

const _schemaWithMultipleFiles = {
  'type': 'object',
  'properties': {
    'files': {
      'type': 'array',
      'title': 'Files',
      'items': {'type': 'string', 'format': 'data-url'},
    },
  },
};

const _schemaWithVideo = {
  'type': 'object',
  'properties': {
    'photo': {'type': 'string', 'format': 'data-url', 'title': 'Photo'},
    'video': {'type': 'string', 'format': 'video', 'title': 'Video'},
  },
};

class _TestApp extends StatelessWidget {
  const _TestApp({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: form));
  }
}
