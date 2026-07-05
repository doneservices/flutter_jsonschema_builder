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
* Added the optional `ui:step` ui schema key to group flat sibling fields
  onto one step without changing the shape of the produced data
* Nested ui schema maps are now applied to nested objects and arrays

## 0.1.3

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.2

* Added `inputDecoration` to `JsonForm` widget
* Added `decoration` to `PropertyFieldWidget` and `PropertySchemaBuilder`

## 0.1.0+3

* Flutter SDK updated to `sdk: '>=3.0.0 <4.0.0'`
