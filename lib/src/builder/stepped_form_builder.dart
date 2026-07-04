import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/object_schema_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/logic/widget_builder_logic.dart';
import 'package:flutter_jsonschema_builder/src/builder/widget_builder.dart';
import 'package:flutter_jsonschema_builder/src/models/json_form_schema_style.dart';
import 'package:flutter_jsonschema_builder/src/models/models.dart';
import 'package:flutter_jsonschema_builder/src/models/stepped_form_config.dart';

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

  JsonFormSteppedConfig get config => widget.config;

  int get _pageCount => _steps.length + (config.showReviewStep ? 1 : 0);

  bool get _isOnReviewPage =>
      config.showReviewStep && _currentPage >= _steps.length;

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

    setState(() {
      final currentId = _pageId(_currentPage);
      _steps = extractJsonFormSteps(widget.mainSchema);

      var newPage = currentId == _reviewPageId
          ? _pageCount - 1
          : _steps.indexWhere((step) => step.id == currentId);
      if (newPage < 0) newPage = _currentPage.clamp(0, _pageCount - 1);

      if (newPage != _currentPage) {
        _currentPage = newPage;
        if (_pageController.hasClients) _pageController.jumpToPage(newPage);
      }
    });
  }

  bool _validateAndSaveCurrent() {
    if (_isOnReviewPage || _currentPage >= _steps.length) return true;

    final formState = _formKeys[_steps[_currentPage].id]?.currentState;
    if (formState == null) return true;

    final isValid = formState.validate();
    if (isValid) formState.save();
    return isValid;
  }

  void _goNext() {
    if (!_validateAndSaveCurrent()) return;

    if (_currentPage >= _pageCount - 1) {
      _trySubmit();
    } else {
      _animateToPage(_currentPage + 1);
    }
  }

  void _goBack() {
    if (_currentPage > 0) _animateToPage(_currentPage - 1);
  }

  void _animateToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: config.transitionDuration,
      curve: config.transitionCurve,
    );
  }

  /// validates every step that has been built (linear navigation guarantees
  /// that is all of them by the time submit is reachable), jumping back to
  /// the first invalid one
  bool _trySubmit() {
    for (var i = 0; i < _steps.length; i++) {
      final formState = _formKeys[_steps[i].id]?.currentState;
      if (formState == null) continue;

      if (!formState.validate()) {
        _animateToPage(i);
        return false;
      }
      formState.save();
    }

    widget.onSubmit();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final uiConfig = WidgetBuilderInherited.of(context).uiConfig;

    return LayoutBuilder(builder: (context, constraints) {
      assert(
        constraints.hasBoundedHeight,
        'JsonForm with JsonFormDisplayMode.stepped expands to fill its parent '
        'and must be given a bounded height (e.g. via Expanded or SizedBox). '
        'Do not place it inside an unconstrained scroll view.',
      );

      return Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(context),
            Expanded(
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
                    return KeyedSubtree(
                      key: const ValueKey<String>(_reviewPageId),
                      child: _buildReviewPage(context),
                    );
                  }
                  final step = _steps[index];
                  return _KeepAlivePage(
                    key: ValueKey<String>(step.id),
                    child: _buildStepPage(context, step),
                  );
                },
              ),
            ),
            _buildControls(context, uiConfig),
          ],
        ),
      );
    });
  }

  Widget _buildProgress(BuildContext context) {
    final totalPages = _pageCount > 0 ? _pageCount : 1;
    if (config.progressBuilder != null) {
      return config.progressBuilder!(context, _currentPage + 1, totalPages);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (_currentPage + 1) / totalPages),
                duration: config.transitionDuration,
                curve: config.transitionCurve,
                builder: (context, value, _) =>
                    LinearProgressIndicator(value: value, minHeight: 4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_currentPage + 1} / $totalPages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStepPage(BuildContext context, JsonFormStep step) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.media != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(child: _buildMedia(context, step.media!)),
            ),
          if (step.title != null)
            Text(step.title!, style: textTheme.headlineSmall),
          if (step.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(step.description!, style: textTheme.bodyMedium),
            ),
          Form(
            key: _formKeyFor(step),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in step.entries)
                  ObjectSchemaInherited(
                    schemaObject: entry.parent,
                    listen: _onObjectSchemaEvent,
                    child: FormFromSchemaBuilder(
                      mainSchema: widget.mainSchema,
                      schema: entry.schema,
                      schemaObject: entry.parent,
                      showDebugElements: widget.showDebugElements,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context, JsonFormMedia media) {
    final custom = config.mediaBuilder?.call(context, media);
    if (custom != null) return custom;

    final height = media.height ?? 200.0;
    switch (media.type) {
      case 'image':
        return Image.network(
          media.src,
          height: height,
          fit: media.fit,
          errorBuilder: (_, __, ___) => SizedBox(height: height),
        );
      case 'asset':
        return Image.asset(
          media.src,
          height: height,
          fit: media.fit,
          errorBuilder: (_, __, ___) => SizedBox(height: height),
        );
      default:
        assert(() {
          debugPrint(
            'JsonForm: no mediaBuilder handled ui:media type "${media.type}" '
            '(src: ${media.src}), nothing will be rendered for it.',
          );
          return true;
        }());
        return const SizedBox.shrink();
    }
  }

  Widget _buildReviewPage(BuildContext context) {
    final widgetBuilderInherited = WidgetBuilderInherited.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.reviewTitle, style: textTheme.headlineSmall),
          if (config.reviewDescription != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(config.reviewDescription!,
                  style: textTheme.bodyMedium),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++)
            for (final entry in _steps[i].entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.schema.title != kNoTitle
                      ? entry.schema.title
                      : entry.schema.id,
                ),
                subtitle: Text(_formatReviewValue(jsonFormDataAtPath(
                    widgetBuilderInherited.data, entry.schema.idKey))),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _animateToPage(i),
              ),
        ],
      ),
    );
  }

  String _formatReviewValue(dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return config.emptyValueText;
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

  Widget _buildControls(
      BuildContext context, JsonFormSchemaUiConfig uiConfig) {
    final isLastPage = _currentPage >= _pageCount - 1;
    final isVertical = config.transitionAxis == Axis.vertical;

    Widget nextButton;
    if (isLastPage) {
      nextButton = uiConfig.submitButtonBuilder != null
          ? uiConfig.submitButtonBuilder!(_trySubmit)
          : ElevatedButton(
              onPressed: _trySubmit,
              child: Text(config.submitButtonText),
            );
    } else {
      nextButton = config.nextButtonBuilder != null
          ? config.nextButtonBuilder!(_goNext)
          : ElevatedButton.icon(
              onPressed: _goNext,
              icon: Icon(isVertical
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right),
              label: Text(config.nextButtonText),
            );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            config.backButtonBuilder != null
                ? config.backButtonBuilder!(_goBack)
                : TextButton.icon(
                    onPressed: _goBack,
                    icon: Icon(isVertical
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_left),
                    label: Text(config.backButtonText),
                  )
          else
            const SizedBox.shrink(),
          nextButton,
        ],
      ),
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
