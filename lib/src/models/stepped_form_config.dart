import 'package:flutter/material.dart';
import 'json_form_media.dart';

/// Builds a widget for a `ui:media` entry. Return `null` to fall back to the
/// built-in rendering (`image`/`asset` types) or to render nothing for
/// unknown types.
typedef JsonFormMediaBuilder = Widget? Function(
    BuildContext context, JsonFormMedia media);

/// Replaces the default progress indicator. [currentStep] is 1-based.
typedef JsonFormStepProgressBuilder = Widget Function(
    BuildContext context, int currentStep, int totalSteps);

/// Builds a navigation button that must invoke [onPressed] when tapped.
typedef JsonFormStepButtonBuilder = Widget Function(VoidCallback onPressed);

/// Configuration for [JsonFormDisplayMode.stepped], the one-question-at-a-time
/// display mode of [JsonForm].
class JsonFormSteppedConfig {
  const JsonFormSteppedConfig({
    this.transitionAxis = Axis.vertical,
    this.transitionDuration = const Duration(milliseconds: 350),
    this.transitionCurve = Curves.easeInOutCubic,
    this.showReviewStep = false,
    this.mediaBuilder,
    this.progressBuilder,
    this.nextButtonBuilder,
    this.backButtonBuilder,
    this.nextButtonText = 'Next',
    this.backButtonText = 'Back',
    this.submitButtonText = 'Submit',
    this.reviewTitle = 'Review your answers',
    this.reviewDescription,
    this.emptyValueText = '—',
  });

  /// [Axis.vertical] slides the next step in from below,
  /// [Axis.horizontal] from the right.
  final Axis transitionAxis;

  final Duration transitionDuration;

  final Curve transitionCurve;

  /// when `true`, a summary of all answers is shown after the last step;
  /// tapping an answer jumps back to its step. When `false`, the last step
  /// submits directly.
  final bool showReviewStep;

  /// renders `ui:media` entries. Called for every media type before the
  /// built-in `image`/`asset` rendering, so it can both add support for
  /// custom types (e.g. `lottie`) and override the built-in ones.
  final JsonFormMediaBuilder? mediaBuilder;

  /// replaces the default linear progress bar + `current / total` counter
  final JsonFormStepProgressBuilder? progressBuilder;

  final JsonFormStepButtonBuilder? nextButtonBuilder;

  final JsonFormStepButtonBuilder? backButtonBuilder;

  final String nextButtonText;

  final String backButtonText;

  /// label of the default submit button. To fully replace the submit button
  /// use [JsonFormSchemaUiConfig.submitButtonBuilder], which is honored in
  /// both display modes.
  final String submitButtonText;

  final String reviewTitle;

  final String? reviewDescription;

  /// shown on the review step for questions without an answer
  final String emptyValueText;
}
