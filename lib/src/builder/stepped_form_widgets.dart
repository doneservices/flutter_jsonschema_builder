import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/models/json_form_media.dart';
import 'package:flutter_jsonschema_builder/src/models/stepped_form_config.dart';

/// The default progress indicator of the stepped display mode: an animated
/// linear bar with a `current / total` counter.
///
/// Colors and bar height come from the ambient [ProgressIndicatorThemeData]
/// and [ColorScheme]; the counter defaults to [TextTheme.bodySmall]. Also
/// usable inside a [JsonFormSteppedConfig.progressBuilder] override.
class JsonFormStepProgress extends StatelessWidget {
  const JsonFormStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOutCubic,
    this.counterStyle,
  });

  /// 1-based index of the step being shown
  final int currentStep;

  final int totalSteps;

  /// how long the bar animates when the step changes
  final Duration duration;

  final Curve curve;

  /// style of the `current / total` counter, defaults to
  /// [TextTheme.bodySmall]
  final TextStyle? counterStyle;

  @override
  Widget build(BuildContext context) {
    final minHeight =
        ProgressIndicatorTheme.of(context).linearMinHeight ?? 4.0;

    return Row(
      children: [
        Expanded(
          // ClipRRect instead of LinearProgressIndicator.borderRadius, which
          // requires Flutter >= 3.13 while this package supports older SDKs
          child: ClipRRect(
            borderRadius: BorderRadius.circular(minHeight / 2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: currentStep / totalSteps),
              duration: duration,
              curve: curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: minHeight,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$currentStep / $totalSteps',
          style: counterStyle ?? Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// The title and description shown above a step's fields.
///
/// Renders nothing when both are null. Styles default to
/// [TextTheme.headlineSmall] and [TextTheme.bodyMedium], overridable per
/// widget or globally via [JsonFormSteppedConfig.stepTitleStyle] and
/// [JsonFormSteppedConfig.stepDescriptionStyle].
class JsonFormStepHeader extends StatelessWidget {
  const JsonFormStepHeader({
    super.key,
    this.title,
    this.description,
    this.titleStyle,
    this.descriptionStyle,
  });

  final String? title;
  final String? description;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    if (title == null && description == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(title!, style: titleStyle ?? textTheme.headlineSmall),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              description!,
              style: descriptionStyle ?? textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Renders a `ui:media` entry: [builder] gets the first chance for every
/// media type (return null to decline), then the built-in `image` (network)
/// and `asset` types; unknown types without a builder render nothing.
class JsonFormStepMedia extends StatelessWidget {
  const JsonFormStepMedia({super.key, required this.media, this.builder});

  final JsonFormMedia media;

  /// typically [JsonFormSteppedConfig.mediaBuilder]
  final JsonFormMediaBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final custom = builder?.call(context, media);
    if (custom != null) return custom;

    if (media.type != 'image' && media.type != 'asset') {
      assert(() {
        debugPrint(
          'JsonForm: no mediaBuilder handled ui:media type "${media.type}" '
          '(src: ${media.src}), nothing will be rendered for it.',
        );
        return true;
      }());
      return const SizedBox.shrink();
    }

    final height = media.height ?? 200.0;
    return Image(
      image: media.type == 'asset'
          ? AssetImage(media.src)
          : NetworkImage(media.src) as ImageProvider,
      height: height,
      fit: media.fit,
      errorBuilder: (_, __, ___) => SizedBox(height: height),
    );
  }
}
