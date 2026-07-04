## 0.2.0

* Added `JsonFormDisplayMode.stepped`: a step-by-step display mode with
  progress bar, per-step validation, vertical/horizontal transitions and an
  optional review step (`JsonFormSteppedConfig`)
* Added `ui:step`, root `ui:steps` and `ui:media` ui schema keys for grouping
  fields into steps and attaching images or animations to them
* Added `JsonFormSteppedConfig.mediaBuilder` for custom media types
  (e.g. Lottie) without adding package dependencies
* Nested ui schema maps are now applied to nested objects and arrays

## 0.1.3

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.2

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.0+3

* Flutter SDK updated to `sdk: '>=3.0.0 <4.0.0'`
