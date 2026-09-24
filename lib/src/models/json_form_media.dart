import 'package:flutter/widgets.dart';

/// Declarative media attached to a form step, parsed from the `ui:media`
/// entry of a field or nested object in the ui schema.
///
/// ```json
/// "firstName": {
///   "ui:media": {
///     "type": "image",
///     "src": "https://example.com/hello.png",
///     "height": 220,
///     "fit": "cover"
///   }
/// }
/// ```
///
/// The built-in renderer understands the types `image` (network url) and
/// `asset` (bundled asset path). Any other type — for example `lottie` —
/// is delegated to [JsonFormSteppedConfig.mediaBuilder] so apps can plug in
/// their own players without this package depending on them.
class JsonFormMedia {
  JsonFormMedia({
    required this.type,
    required this.src,
    this.height,
    this.fit = BoxFit.contain,
  });

  /// tolerant of loosely-typed json (e.g. a string height) — media config
  /// often comes from hand-written or server-built ui schemas and must not
  /// crash form construction
  factory JsonFormMedia.fromJson(Map<String, dynamic> json) {
    final height = json['height'];
    return JsonFormMedia(
      type: json['type']?.toString() ?? 'image',
      src: json['src']?.toString() ?? '',
      height: height is num
          ? height.toDouble()
          : height is String
          ? double.tryParse(height)
          : null,
      fit: BoxFit.values.asNameMap()[json['fit']] ?? BoxFit.contain,
    );
  }

  /// `image` and `asset` are rendered by the package itself, any other value
  /// is handed to the app's media builder.
  final String type;

  /// Url, asset path, or whatever the [type]'s renderer expects.
  final String src;

  /// Rendered height in logical pixels. Built-in step images use their
  /// intrinsic height when this is omitted.
  final double? height;

  final BoxFit fit;
}

/// Welcome screen shown before the first step of the stepped display mode,
/// parsed from the root-level `ui:intro` entry of the ui schema:
///
/// ```json
/// "ui:intro": {
///   "title": "Welcome!",
///   "description": "Takes about **2 minutes**.",
///   "media": {"type": "image", "src": "https://example.com/hi.png"},
///   "buttonText": "Start"
/// }
/// ```
///
/// Every key is optional: `title`/`description` fall back to the root
/// schema's own, `buttonText` to [JsonFormSteppedConfig.introButtonText].
/// `"ui:intro": {}` is enough for an intro built from the schema itself.
class JsonFormIntro {
  JsonFormIntro({this.title, this.description, this.media, this.buttonText});

  factory JsonFormIntro.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    return JsonFormIntro(
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      media: media is Map
          ? JsonFormMedia.fromJson(Map<String, dynamic>.from(media))
          : null,
      buttonText: json['buttonText']?.toString(),
    );
  }

  final String? title;

  /// rendered as Markdown, like question descriptions
  final String? description;

  final JsonFormMedia? media;

  final String? buttonText;
}
