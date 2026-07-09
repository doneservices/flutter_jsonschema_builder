import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/object_schema_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/stepped_form_widgets.dart';
import 'package:flutter_jsonschema_builder/src/builder/widget_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';
import 'package:flutter_jsonschema_builder/src/models/stepped_form_config.dart';

/// bottom scroll padding used until the floating controls have been
/// measured; afterwards the measured height (plus a gap) takes over so
/// custom button builders and text scaling can't hide the last field
const _kFallbackControlsClearance = 80.0;

/// breathing room between the lowest scrolled-to field and the controls
const _kControlsGap = 16.0;

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
    this.showTitle = true,
  });

  final SchemaObject mainSchema;
  final JsonFormSteppedConfig config;

  /// called once every step form validated and saved successfully
  final VoidCallback onSubmit;

  final bool showDebugElements;
  final EdgeInsets padding;

  /// whether to show the form's top-level title above the progress bar
  final bool showTitle;

  @override
  State<SteppedFormBuilder> createState() => _SteppedFormBuilderState();
}

class _SteppedFormBuilderState extends State<SteppedFormBuilder> {
  static const _reviewPageId = '__review__';

  late List<JsonFormStep> _steps;
  late final PageController _pageController;
  final Map<String, GlobalKey<FormState>> _formKeys = {};
  int _currentPage = 0;

  final GlobalKey _controlsKey = GlobalKey();

  /// bottom padding for the pages' scroll views, kept in sync with the
  /// rendered height of the floating controls (custom builders and text
  /// scaling make that height unknowable up front)
  double _controlsClearance = _kFallbackControlsClearance;

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

      var newPage =
          currentId == _reviewPageId
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

  /// called by a field when it receives a value that could advance the form
  /// (enum selection). Only advances single-field steps so grouped steps
  /// still wait for the next button; deferred a frame so the field finishes
  /// its own onChanged (didChange/validate) before the page animates out.
  void _requestAutoAdvance() {
    if (!config.autoAdvanceOnSelect || _isTransitioning) return;
    if (_currentPage >= _steps.length) return;
    if (_steps[_currentPage].schemas.length != 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goNext();
    });
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
    final nodes = _textFieldsOn(page);
    return nodes.isEmpty ? null : nodes.first;
  }

  /// focus nodes of every text field on [page], in visual order; empty for
  /// the review page or one that was never built
  List<FocusNode> _textFieldsOn(int page) {
    if (page >= _steps.length) return const [];
    final formContext = _formKeys[_steps[page].id]?.currentContext;
    if (formContext == null) return const [];

    final nodes = <FocusNode>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is EditableText) {
        nodes.add(widget.focusNode);
        return;
      }
      element.visitChildren(visit);
    }

    (formContext as Element).visitChildren(visit);
    return nodes;
  }

  /// keyboard action button pressed in a text field: move to the next text
  /// field on the same page, or to the next page when it was the last one
  void _onTextSubmitted() {
    if (_isTransitioning) return;
    final fields = _textFieldsOn(_currentPage);
    final focusedIndex = fields.indexWhere((node) => node.hasFocus);
    if (focusedIndex >= 0 && focusedIndex < fields.length - 1) {
      fields[focusedIndex + 1].requestFocus();
    } else if (_currentPage < _pageCount - 1) {
      _goNext();
    }
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

  /// re-measures the floating controls after this frame; build schedules
  /// this every time, so theme/text-scale changes and custom builders that
  /// change size converge on the right clearance within a frame
  void _scheduleControlsMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _controlsKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final clearance = box.size.height + _kControlsGap;
      if ((clearance - _controlsClearance).abs() > 0.5) {
        setState(() => _controlsClearance = clearance);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleControlsMeasurement();
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'JsonForm with JsonFormDisplayMode.stepped expands to fill its parent '
          'and must be given a bounded height (e.g. via Expanded or SizedBox). '
          'Do not place it inside an unconstrained scroll view.',
        );

        final totalPages = _pageCount > 0 ? _pageCount : 1;

        return SteppedFormScope(
          requestAutoAdvance: _requestAutoAdvance,
          onTextSubmitted: _onTextSubmitted,
          controlsClearance: _controlsClearance,
          child: Padding(
            padding: widget.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // the form's title, like classic mode's header — but smaller,
                // since here it stays visible on every step
                if (widget.showTitle && widget.mainSchema.title != kNoTitle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.mainSchema.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign:
                          WidgetBuilderInherited.of(
                            context,
                          ).uiConfig.titleAlign,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child:
                      config.progressBuilder != null
                          ? config.progressBuilder!(
                            context,
                            _currentPage + 1,
                            totalPages,
                          )
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
                            if (key.value == _reviewPageId)
                              return _steps.length;
                            final index = _steps.indexWhere(
                              (step) => step.id == key.value,
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) {
                            if (index >= _steps.length) {
                              return _ReviewPage(
                                key: const ValueKey<String>(_reviewPageId),
                                steps: _steps,
                                config: config,
                                onEditStep: _animateToPage,
                                bottomClearance: _controlsClearance,
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
                                  bottomClearance: _controlsClearance,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: KeyedSubtree(
                          key: _controlsKey,
                          child: _StepControls(
                            config: config,
                            isFirstPage: _currentPage == 0,
                            isLastPage: _currentPage >= _pageCount - 1,
                            onBack: _goBack,
                            onNext: _goNext,
                            onSubmit: _trySubmit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Exposes the current stepped form's navigation hooks to descendant
/// fields, so an enum selection or a keyboard action button deep in the
/// tree can ask to move on.
class SteppedFormScope extends InheritedWidget {
  const SteppedFormScope({
    super.key,
    required this.requestAutoAdvance,
    required this.onTextSubmitted,
    required this.controlsClearance,
    required super.child,
  });

  final VoidCallback requestAutoAdvance;

  /// measured height of the floating controls; fields use it as bottom
  /// [TextField.scrollPadding] so focus-driven auto-scroll clears them
  final double controlsClearance;

  /// keyboard action button (enter/done/next) pressed in a text field:
  /// focus the step's next text field, or advance to the next page
  final VoidCallback onTextSubmitted;

  static SteppedFormScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SteppedFormScope>();

  @override
  bool updateShouldNotify(SteppedFormScope oldWidget) =>
      controlsClearance != oldWidget.controlsClearance;
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
    required this.bottomClearance,
  });

  final JsonFormStep step;
  final GlobalKey<FormState> formKey;
  final SchemaObject mainSchema;
  final JsonFormSteppedConfig config;
  final bool showDebugElements;
  final ValueSetter<ObjectSchemaEvent?> onSchemaEvent;

  /// measured height of the floating controls, so the last field can
  /// always scroll clear of them
  final double bottomClearance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 8, bottom: bottomClearance),
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
    required this.bottomClearance,
  });

  final List<JsonFormStep> steps;
  final JsonFormSteppedConfig config;
  final ValueSetter<int> onEditStep;
  final double bottomClearance;

  @override
  Widget build(BuildContext context) {
    final data = WidgetBuilderInherited.of(context).data;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 8, bottom: bottomClearance),
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
                subtitle: _valueWidget(
                  schema,
                  jsonFormDataAtPath(data, schema.idKey),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => onEditStep(i),
              ),
        ],
      ),
    );
  }

  /// file answers are data-url strings (or lists of them) — never show
  /// those; render one file icon per uploaded file instead
  Widget _valueWidget(Schema schema, dynamic value) {
    final isFileField =
        schema is SchemaProperty && schema.format == PropertyFormat.dataurl;
    if (isFileField) {
      final count =
          value == null || (value is List && value.isEmpty)
              ? 0
              : value is List
              ? value.length
              : 1;
      if (count == 0) return const Text('—');
      return Row(
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.insert_drive_file_outlined, size: 18),
            ),
        ],
      );
    }
    return Text(_formatValue(schema, value));
  }

  String _formatValue(Schema schema, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return '—';
    }
    if (value is bool) return config.formatBoolean(value);
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
      nextButton =
          uiConfig.submitButtonBuilder != null
              ? uiConfig.submitButtonBuilder!(onSubmit)
              : ElevatedButton(
                onPressed: onSubmit,
                child: Text(config.submitButtonText),
              );
    } else {
      nextButton =
          config.nextButtonBuilder != null
              ? config.nextButtonBuilder!(onNext)
              : ElevatedButton.icon(
                onPressed: onNext,
                icon: Icon(
                  isVertical
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                ),
                label: Text(config.nextButtonText),
              );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isFirstPage)
          config.backButtonBuilder != null
              ? config.backButtonBuilder!(onBack)
              // deliberately quieter than the next/submit button, but with
              // an opaque background so it stays legible over anything the
              // page scrolls underneath it
              : TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                icon: Icon(
                  isVertical
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_left,
                ),
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
