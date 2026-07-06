# Changelog

## 0.2.0

* Added `JsonFormDisplayMode.stepped`: a step-by-step display mode with
  progress bar, per-step validation, vertical/horizontal transitions and an
  optional review step (`JsonFormSteppedConfig`)
* Steps derive from the schema structure: scalar fields get their own step,
  nested objects become one step titled by the object's own title and
  description, so a plain JSON schema works in both display modes
* Added the `ui:media` ui schema key for attaching images or animations to a
  step, and `JsonFormSteppedConfig.mediaBuilder` for custom media types
  (e.g. Lottie) without adding package dependencies
* Nested ui schema maps are now applied to nested objects and arrays;
  object-level `ui:*` keys apply to the object itself and no longer leak
  onto its child fields, and a partial `ui:order` keeps unlisted fields
  after the listed ones instead of reordering them first

## 0.1.3

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.2

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.0+3

* Flutter SDK updated to `sdk: '>=3.0.0 <4.0.0'`
