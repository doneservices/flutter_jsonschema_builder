import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('demo boots into the stepped form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // first step of the stepped demo form
    expect(find.text('About you'), findsOneWidget);
    expect(find.textContaining('First name'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // the mode toggle lives in the settings menu (bounded pumps: the
    // looping Lottie animation would keep pumpAndSettle from settling)
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Switch to classic'), findsOneWidget);
  });

  testWidgets('image and video fields offer the same three sources', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Switch to classic'));
    await tester.pumpAndSettle();

    expect(find.text('Record video'), findsNothing);
    expect(find.text('Add File'), findsNWidgets(3));

    final imageButton = find.text('Add File').first;
    await tester.ensureVisible(imageButton);
    await tester.tap(imageButton);
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final videoButton = find.text('Add File').last;
    await tester.ensureVisible(videoButton);
    await tester.tap(videoButton);
    await tester.pumpAndSettle();

    expect(find.text('Record video'), findsOneWidget);
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });

  testWidgets('demo builds previews for selected images and videos', (
    WidgetTester tester,
  ) async {
    final filesBuilder = buildDemoFileUiConfig().filesBuilder;
    expect(filesBuilder, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: filesBuilder!([
            SchemaFormFile(
              name: 'avatar.png',
              value: 'data:image/png;base64,',
              bytes: Uint8List(0),
            ),
            SchemaFormFile(
              name: 'clip.mp4',
              value: '/tmp/clip.mp4',
              bytes: Uint8List(0),
            ),
          ], onRemove: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const Key('demo-image-preview')), findsOneWidget);
    expect(find.byKey(const Key('demo-video-preview')), findsOneWidget);

    final image = tester.widget<Image>(
      find.byKey(const Key('demo-image-preview')),
    );
    expect(image.width, 140);
    expect(image.height, isNull);
    expect(image.fit, BoxFit.fitWidth);
    expect(
      find.descendant(
        of: find.byKey(const Key('demo-video-preview')),
        matching: find.byType(AspectRatio),
      ),
      findsOneWidget,
    );
  });

  testWidgets('review file previews are compact thumbnails', (tester) async {
    final image = SchemaProperty.fromJson('image', {
      'type': 'string',
      'format': 'data-url',
    });
    image.setUi({
      'ui:options': {'fileType': 'image'},
    });
    final video = SchemaProperty.fromJson('video', {
      'type': 'string',
      'format': 'video',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    demoReviewFileBuilder(context, image, const [
                      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
                          'CAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                    ]),
                    demoReviewFileBuilder(context, video, const [
                      '/tmp/clip.mp4',
                    ]),
                  ],
                ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('demo-review-image-preview')), findsOneWidget);
    expect(find.byKey(const Key('demo-review-video-preview')), findsOneWidget);
    final videoClip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byKey(const Key('demo-review-video-preview')),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(videoClip.borderRadius, BorderRadius.circular(6));
    expect(
      tester.getSize(find.byKey(const Key('demo-review-video-preview'))).width,
      lessThanOrEqualTo(64),
    );
  });
}
