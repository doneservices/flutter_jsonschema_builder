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

  final double? height;

  final BoxFit fit;
}
