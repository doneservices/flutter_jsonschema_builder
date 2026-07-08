import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/object_schema_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/stepped_form_widgets.dart';
import 'package:flutter_jsonschema_builder/src/builder/widget_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';
import 'package:flutter_jsonschema_builder/src/models/stepped_form_config.dart';

/// bottom padding inside a step's scroll view so its content can scroll
/// clear of the navigation controls floating above it
const _kControlsClearance = 80.0;

/// Renders [mainSchema] one step at a time: a progress header, a page per
/// step (see [extractJsonFormSteps]) with optional `ui:media`, and
/// back/next navigation gated by the current step's validators.
class SteppedFormBuilder extends StatefulWidget {
  const SteppedFormBuilder({
    super.key,
    required this.mainSchema,
    required this.config,
    required this.onSubmit,
    this.showDebugElements = true,
    this.padding = const EdgeInsets.all(16),
  });

  final SchemaObject mainSchema;
  final JsonFormSteppedConfig config;

  /// called once every step form validated and saved successfully
  final VoidCallback onSubmit;

  final bool showDebugElements;
  final EdgeInsets padding;

  @override
  State<SteppedFormBuilder> createState() => _SteppedFormBuilderState();
}

class _SteppedFormBuilderState extends State<SteppedFormBuilder> {
  static const _reviewPageId = '__review__';

  late List<JsonFormStep> _steps;
  late final PageController _pageController;
  final Map<String, GlobalKey<FormState>> _formKeys = {};
  int _currentPage = 0;

  /// a double-tap must not navigate twice or submit twice; taps are ignored
  /// while a page transition runs, and [_isSubmitting] swallows duplicate
  /// taps delivered before the consumer's onSubmit had a frame to react
  bool _isTransitioning = false;
  bool _isSubmitting = false;

  JsonFormSteppedConfig get config => widget.config;

  int get _pageCount => _steps.length + (config.showReviewStep ? 1 : 0);

  String _pageId(int page) =>
      page < _steps.length ? _steps[page].id : _reviewPageId;

  @override
  void initState() {
    super.initState();
    _steps = extractJsonFormSteps(widget.mainSchema);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GlobalKey<FormState> _formKeyFor(JsonFormStep step) =>
      _formKeys.putIfAbsent(step.id, () => GlobalKey<FormState>());

  /// dependencies can add/remove properties while the form is displayed;
  /// re-extract the steps and stay on the step the user is looking at
  void _onObjectSchemaEvent(ObjectSchemaEvent? event) {
    if (event is! ObjectSchemaDependencyEvent) return;
    // dependency events can arrive after an async gap (see
    // _removeCreatedItemsSafeMode), possibly after this state is disposed
    if (!mounted) return;

    setState(() {
      final currentId = _pageId(_currentPage);
      _steps = extractJsonFormSteps(widget.mainSchema);

      var newPage = currentId == _reviewPageId
          ? _pageCount - 1
          : _steps.indexWhere((step) => step.id == currentId);
      // the current step may have been removed — or every step (clamping
      // against an empty page range would throw)
      if (newPage < 0) {
        newPage = _pageCount > 0 ? _currentPage.clamp(0, _pageCount - 1) : 0;
      }

      if (newPage != _currentPage) {
        _currentPage = newPage;
        if (_pageController.hasClients) _pageController.jumpToPage(newPage);
      }
    });
  }

  bool _validateAndSaveCurrent() {
    if (_currentPage >= _steps.length) return true;

    final formState = _formKeys[_steps[_currentPage].id]?.currentState;
    if (formState == null) return true;

    final isValid = formState.validate();
    if (isValid) formState.save();
    return isValid;
  }

  /// only reachable from non-last pages: the last page renders the submit
  /// button (wired to [_trySubmit]) instead of the next button.
  /// Checks the transition guard itself so a tap mid-transition doesn't
  /// even validate (and show errors on) the incoming page.
  void _goNext() {
    if (_isTransitioning) return;
    if (_validateAndSaveCurrent()) _animateToPage(_currentPage + 1);
  }

  void _goBack() {
    if (_currentPage > 0) _animateToPage(_currentPage - 1);
  }

  /// every page change funnels through here (including the review page's
  /// tap-to-edit), so this is where re-entrant transitions are blocked
  void _animateToPage(int page) {
    if (_isTransitioning) return;
    // captured before the transition: the old field keeps focus while its
    // page animates out, so the keyboard doesn't flicker mid-transition
    final followFocus = _textInputHasFocus;
    setState(() => _currentPage = page);
    _isTransitioning = true;
    _pageController
        .animateToPage(
          page,
          duration: config.transitionDuration,
          curve: config.transitionCurve,
        )
        .whenComplete(() {
      _isTransitioning = false;
      if (mounted) _syncKeyboardWithPage(page, followFocus);
    });
  }

  /// the keyboard follows the navigation: when the user was typing, focus
  /// moves to the first text field of the new page; when the new page has
  /// none — or is the review page — focus drops and the keyboard dismisses
  void _syncKeyboardWithPage(int page, bool followFocus) {
    final target = followFocus ? _firstTextFieldOn(page) : null;
    if (target != null) {
      target.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// whether the focused widget is a text field — the signal that the
  /// software keyboard is up (and behaves sensibly where there is none).
  /// Text fields attach their node to a Focus widget inside EditableText,
  /// so the text field is found above the focused context, not at it.
  bool get _textInputHasFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// focus node of the first text field on [page]; null for the review
  /// page, a page without text input, or one that was never built
  FocusNode? _firstTextFieldOn(int page) {
    if (page >= _steps.length) return null;
    final formContext = _formKeys[_steps[page].id]?.currentContext;
    if (formContext == null) return null;

    FocusNode? node;
    void visit(Element element) {
      if (node != null) return;
      final widget = element.widget;
      if (widget is EditableText) {
        node = widget.focusNode;
        return;
      }
      element.visitChildren(visit);
    }

    (formContext as Element).visitChildren(visit);
    return node;
  }

  /// validates every step, jumping back to the first invalid one. A step
  /// whose form was never built (possible when a dependency inserts steps
  /// behind the current page) is not silently trusted — the user is taken
  /// there instead.
  bool _trySubmit() {
    // checked here too: the guard in _animateToPage only stops the page
    // change, not a submit fired while a transition is still running
    if (_isTransitioning || _isSubmitting) return false;

    for (var i = 0; i < _steps.length; i++) {
      final formState = _formKeys[_steps[i].id]?.currentState;
      if (formState == null || !formState.validate()) {
        _animateToPage(i);
        return false;
      }
      formState.save();
    }

    _isSubmitting = true;
    // re-arm on the next frame: the tap's ink ripple guarantees one, and by
    // then the consumer had the chance to navigate away or disable the form
    WidgetsBinding.instance.addPostFrameCallback((_) => _isSubmitting = false);
    widget.onSubmit();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      assert(
        constraints.hasBoundedHeight,
        'JsonForm with JsonFormDisplayMode.stepped expands to fill its parent '
        'and must be given a bounded height (e.g. via Expanded or SizedBox). '
        'Do not place it inside an unconstrained scroll view.',
      );

      final totalPages = _pageCount > 0 ? _pageCount : 1;

      return Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: config.progressBuilder != null
                  ? config.progressBuilder!(
                      context, _currentPage + 1, totalPages)
                  : JsonFormStepProgress(
                      currentStep: _currentPage + 1,
                      totalSteps: totalPages,
                      duration: config.transitionDuration,
                      curve: config.transitionCurve,
                    ),
            ),
            // the controls float on top of the page content instead of
            // stacking below it, so the page keeps the full height — which
            // matters most when the software keyboard halves it
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      scrollDirection: config.transitionAxis,
                      itemCount: _pageCount,
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<String>) return null;
                        if (key.value == _reviewPageId) return _steps.length;
                        final index =
                            _steps.indexWhere((step) => step.id == key.value);
                        return index < 0 ? null : index;
                      },
                      itemBuilder: (context, index) {
                        if (index >= _steps.length) {
                          return _ReviewPage(
                            key: const ValueKey<String>(_reviewPageId),
                            steps: _steps,
                            config: config,
                            onEditStep: _animateToPage,
                          );
                        }
                        final step = _steps[index];
                        return _KeepAlivePage(
                          key: ValueKey<String>(step.id),
                          // silence animations (e.g. looping ui:media) on
                          // kept-alive off-screen pages
                          child: TickerMode(
                            enabled: index == _currentPage,
                            child: _StepPage(
                              step: step,
                              formKey: _formKeyFor(step),
                              mainSchema: widget.mainSchema,
                              config: config,
                              showDebugElements: widget.showDebugElements,
                              onSchemaEvent: _onObjectSchemaEvent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _StepControls(
                      config: config,
                      isFirstPage: _currentPage == 0,
                      isLastPage: _currentPage >= _pageCount - 1,
                      onBack: _goBack,
                      onNext: _goNext,
                      onSubmit: _trySubmit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// One step of the form: media, header and the step's fields wrapped in
/// their own [Form] so navigation can validate just this step.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.formKey,
    required this.mainSchema,
    required this.config,
    required this.showDebugElements,
    required this.onSchemaEvent,
  });

  final JsonFormStep step;
  final GlobalKey<FormState> formKey;
  final SchemaObject mainSchema;
  final JsonFormSteppedConfig config;
  final bool showDebugElements;
  final ValueSetter<ObjectSchemaEvent?> onSchemaEvent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: _kControlsClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.media != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: JsonFormStepMedia(
                  media: step.media!,
                  builder: config.mediaBuilder,
                ),
              ),
            ),
          JsonFormStepHeader(
            title: step.title,
            description: step.description,
            titleStyle: config.stepTitleStyle,
            descriptionStyle: config.stepDescriptionStyle,
          ),
          Form(
            key: formKey,
            child: ObjectSchemaInherited(
              schemaObject: step.parent,
              listen: onSchemaEvent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final schema in step.schemas)
                    FormFromSchemaBuilder(
                      mainSchema: mainSchema,
                      schema: schema,
                      showDebugElements: showDebugElements,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary of every answer with tap-to-edit, shown after the last step when
/// [JsonFormSteppedConfig.showReviewStep] is enabled.
class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    super.key,
    required this.steps,
    required this.config,
    required this.onEditStep,
  });

  final List<JsonFormStep> steps;
  final JsonFormSteppedConfig config;
  final ValueSetter<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final data = WidgetBuilderInherited.of(context).data;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: _kControlsClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JsonFormStepHeader(
            title: config.reviewTitle,
            description: config.reviewDescription,
            titleStyle: config.stepTitleStyle,
            descriptionStyle: config.stepDescriptionStyle,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            for (final schema in steps[i].schemas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  schema.title != kNoTitle ? schema.title : schema.id,
                ),
                subtitle: Text(_formatValue(
                    schema, jsonFormDataAtPath(data, schema.idKey))),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => onEditStep(i),
              ),
        ],
      ),
    );
  }

  String _formatValue(Schema schema, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return '—';
    }
    // show the enum's display name, like the field itself does
    if (schema is SchemaProperty &&
        schema.enumm != null &&
        schema.enumNames != null) {
      final index = schema.enumm!.indexOf(value);
      if (index >= 0 && index < schema.enumNames!.length) {
        return schema.enumNames![index].toString();
      }
    }
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }
}

/// Back/next navigation row, floating over the page content; the next
/// button becomes the submit button on the last page, honoring
/// [JsonFormSchemaUiConfig.submitButtonBuilder]. The defaults are buttons
/// with their own container color so they stay legible over anything the
/// page scrolls underneath them.
class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.config,
    required this.isFirstPage,
    required this.isLastPage,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final JsonFormSteppedConfig config;
  final bool isFirstPage;
  final bool isLastPage;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueGetter<bool> onSubmit;

  @override
  Widget build(BuildContext context) {
    final uiConfig = WidgetBuilderInherited.of(context).uiConfig;
    final isVertical = config.transitionAxis == Axis.vertical;

    Widget nextButton;
    if (isLastPage) {
      nextButton = uiConfig.submitButtonBuilder != null
          ? uiConfig.submitButtonBuilder!(onSubmit)
          : ElevatedButton(
              onPressed: onSubmit,
              child: Text(config.submitButtonText),
            );
    } else {
      nextButton = config.nextButtonBuilder != null
          ? config.nextButtonBuilder!(onNext)
          : ElevatedButton.icon(
              onPressed: onNext,
              icon: Icon(isVertical
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right),
              label: Text(config.nextButtonText),
            );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isFirstPage)
          config.backButtonBuilder != null
              ? config.backButtonBuilder!(onBack)
              : FilledButton.tonalIcon(
                  onPressed: onBack,
                  icon: Icon(isVertical
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_left),
                  label: Text(config.backButtonText),
                )
        else
          const SizedBox.shrink(),
        nextButton,
      ],
    );
  }
}

/// keeps visited pages alive inside the [PageView] so field state (text,
/// selections) survives back/forward navigation
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
