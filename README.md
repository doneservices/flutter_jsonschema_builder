<p align="center">

  <h3 align="center">flutter_jsonschema_builder</h3>

  <p align="center">
    A simple <a href="https://flutter.dev/">Flutter</a> widget capable of using <a href="http://json-schema.org/">JSON Schema</a> to declaratively build and customize web forms.
    <br />
    Inspired by <a href="https://github.com/rjsf-team/react-jsonschema-form">react-jsonschema-form</a>
    <br />    
</p>

## Installation

Add dependency to pubspec.yaml

```
dependencies:
  ...
  flutter_jsonschema_builder: ^0.0.1+1
```

Run in your terminal

```
flutter packages get
```

See the [File Picker Installation](https://github.com/miguelpruivo/plugins_flutter_file_picker) for file fields.

## Usage

```dart
import 'package:flutter_jsonschema_builder/flutter_jsonschema_builder.dart';


final jsonSchema = {
  "title": "A registration form",
  "description": "A simple form example.",
  "type": "object",
  "required": [
    "firstName",
    "lastName"
  ],
  "properties": {
    "firstName": {
      "type": "string",
      "title": "First name",
      "default": "Chuck"
    },
    "lastName": {
      "type": "string",
      "title": "Last name"
    },
    "telephone": {
      "type": "string",
      "title": "Telephone",
      "minLength": 10
    }
  }
}



@override
Widget build(BuildContext context) {
  return Scaffold(
    body: JsonForm(
      jsonSchema: jsonSchema,
      onFormDataSaved: (data) {
        inspect(data);
      },
    ),
  );
}
```
<img width="364" alt="image" src="https://user-images.githubusercontent.com/58694638/187986742-3b1aa96c-4a85-42a3-aec0-dac62a8515a4.png">

### Using arrays & Files
```dart
  final json = '''
{
  "title": "Example 2",
  "type": "object",
  "properties": {
   "listOfStrings": {
      "type": "array",
      "title": "A list of strings",
      "items": {
        "type": "string",
        "title" : "Write your item",
        "default": "bazinga"
      }
    },
    "files": {
      "type": "array",
      "title": "Multiple files",
      "items": {
        "type": "string",
        "format": "data-url"
      }
    }
  }
}
  ''';

### Using UI Schema
```dart

final uiSchema = '''
{
  "selectYourCola": {
    "ui:widget": "radio"
  }
 }
''';

```
<img width="348" alt="image" src="https://user-images.githubusercontent.com/58694638/187996261-ab3be73d-35e0-40c5-a0de-47900b64f1be.png">


### Stepped display mode

`JsonForm` can walk through the form one question at a time — a
conversational, wizard-style experience — instead of rendering everything on
one page. Enable it with `displayMode`:

```dart
JsonForm(
  jsonSchema: jsonSchema,
  uiSchema: uiSchema,
  displayMode: JsonFormDisplayMode.stepped,
  steppedConfig: JsonFormSteppedConfig(
    transitionAxis: Axis.vertical, // or Axis.horizontal
    showReviewStep: true,          // summary page before submitting
  ),
  onFormDataSaved: (data) => inspect(data),
)
```

The stepped mode expands to fill its parent, so give it a bounded height
(a `Scaffold` body, `Expanded`, `SizedBox`...) instead of wrapping it in a
scroll view. It shows a progress bar with a step counter, validates the
current step before advancing, and keeps entered values when navigating back.
Back/next buttons, the progress bar and all labels can be customized through
`JsonFormSteppedConfig`; the submit button reuses
`JsonFormSchemaUiConfig.submitButtonBuilder`.

#### Defining steps

By default every field is its own step, and nested objects are flattened into
the sequence. Group fields onto a shared step with `ui:step`, keep a nested
object together by giving the object itself a `ui:step`, and configure a
group's title, description and media in the root `ui:steps` block:

```json
{
  "ui:steps": {
    "name": {
      "title": "What should we call you?",
      "description": "First things first — introduce yourself.",
      "media": {"type": "image", "src": "https://example.com/hello.png"}
    }
  },
  "firstName": {"ui:step": "name"},
  "lastName": {"ui:step": "name"}
}
```

#### Step media: images and Lottie animations

Each step can show an image or an animation above its fields, declared in the
ui schema with `ui:media` (per field) or `ui:steps.<group>.media` (per group):

```json
"email": {
  "ui:media": {
    "type": "image",
    "src": "https://example.com/mail.png",
    "height": 160,
    "fit": "cover"
  }
}
```

The package renders the types `image` (network url) and `asset` (bundled
asset) out of the box. Any other type is handed to
`JsonFormSteppedConfig.mediaBuilder`, so the package stays dependency-free
while apps bring their own players — e.g. Lottie:

```dart
steppedConfig: JsonFormSteppedConfig(
  mediaBuilder: (context, media) {
    if (media.type == 'lottie') {
      return Lottie.asset(media.src, height: media.height ?? 160);
    }
    return null; // fall back to the built-in image/asset rendering
  },
),
```

See `example/lib/main.dart` for a runnable demo with both modes, grouped
steps, an image step and a Lottie step.

### Custom File Handler 

```dart
customFileHandler: () => {
  'profile_photo': () async {
    
    return [
      File(
          'https://cdn.mos.cms.futurecdn.net/LEkEkAKZQjXZkzadbHHsVj-970-80.jpg')
    ];
  },
  '*': null
}
```

### Initial File Value Handler

As file can be represented as any string, even a URL, so we need a way to convert back that string into an actual file value, we can provide `initialFileValueHandler` for this case

```dart
initialFileValueHandler: () => {
  'profile_photo': (dynamic defaultValue) async {
    if(defaultValue is List) 
    // fetch list of images logic here
    return;
    if(defaultValue is String){
      final file = await fetchOurFileFromUrl(defaultValue);
      return [SchemaFormFile(name: file.name, bytes: await file.readAsBytes(), value: defaultValue )]
    }
    
  },
  '*': null
}

Future<List<SchemaFormFile>?> _defaultInitialFileValueHandler(
    dynamic defaultValue) async {
  Future<SchemaFormFile?> schemaFileFromUrl(String url) async {
    // file fetching logic here
  }

  if (defaultValue is List) {
    final result =
        await Future.wait(defaultValue.cast<String>().map(schemaFileFromUrl));
    return result.whereType<SchemaFormFile>().toList();
  }

  if (defaultValue is String) {
    final file = await schemaFileFromUrl(defaultValue);
    if (file != null) return [file];
  }

  return null;
}
```

### Using Custom Validator

```dart
customValidatorHandler: () => {
  'selectYourCola': (value) {
    if (value == 0) {
      return 'Cola 0 is not allowed';
    }
  }
},
```
<img width="659" alt="image" src="https://user-images.githubusercontent.com/58694638/187993619-15adcfaf-2a0c-4ae0-ada4-4617d814f85e.png">


### TODO

- [ ] Add all examples
- [ ] OnChanged
- [ ] References
- [ ] pub.dev

