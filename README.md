# Elyra Vita

Elyra Vita is a SwiftUI-based iOS health and lifestyle app focused on making everyday wellbeing easier to understand and manage.

This repository contains the current learning and development version of the project. It is being built step by step to explore modern SwiftUI architecture, SwiftData persistence, reusable components, and a clean feature-based project structure.

## Current status

Elyra Vita is an active work in progress. The project currently contains the foundation of the app experience:

- A tab-based iOS interface for Overview, Nutrition, Planning, Recipes, and Progress
- Shared date navigation for the Overview and Nutrition areas
- A reusable toolbar and date picker flow
- User settings stored with SwiftData
- Preset and custom accent colors
- Light and dark appearance preferences
- Reusable app background, card, and UI components
- SwiftUI previews and initial unit/UI test targets

The nutrition, health, weight, and calorie features will be connected to real data as development continues. Placeholder values are intentionally used while the interface is being designed.

## Technology

- Swift
- SwiftUI
- SwiftData
- CloudKit-ready project configuration
- Xcode
- iOS 18.6+

## Project structure

```text
Elyra_Vita/
├── App/
│   ├── ContentView.swift
│   ├── Elyra_VitaApp.swift
│   └── Navigation/
├── Configuration/
├── Features/
│   ├── 1.Overview/
│   ├── 2.Nutrition/
│   ├── 3.Planning/
│   ├── 4.Recipies/
│   ├── 5.Progress/
│   └── Settings/
├── Resources/
└── Shared/
    ├── Colors/
    └── Components/
```

The project is organized by feature so that each area can grow independently. Shared components and styling are kept separate from feature-specific screens.

## Architecture principles

Elyra Vita follows a simple SwiftUI architecture designed to remain approachable while the project grows:

- `ContentView` owns app-level navigation and shared state.
- Feature views are responsible for arranging their own screens.
- Reusable components focus on one visual or functional responsibility.
- SwiftData models contain persistent application data.
- Settings and appearance values flow down into child views through properties.
- Shared modifiers provide consistent styling across the app.

This separation keeps the UI easier to understand and makes individual components simple to preview and test.

## Getting started

### Requirements

- macOS with Xcode installed
- An iOS Simulator or a connected iPhone
- A valid Apple developer setup for running on a physical device

### Run the project

1. Clone the repository.

   ```bash
   git clone https://github.com/pasukistudio/elyra-vita.git
   cd elyra-vita
   ```

2. Open `Elyra_Vita.xcodeproj` in Xcode.

3. Select the `Elyra_Vita` scheme.

4. Choose an iOS Simulator or connected device.

5. Build and run with `⌘R`.

## Testing

The repository includes separate unit-test and UI-test targets:

- `Elyra_VitaTests`
- `Elyra_VitaUITests`

Run the test suite in Xcode with:

```text
⌘U
```

The project can also be built from the command line:

```bash
xcodebuild \
  -project Elyra_Vita.xcodeproj \
  -scheme Elyra_Vita \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Roadmap

Planned development areas include:

- Connecting calorie values to real meal data
- Nutrition and meal tracking
- HealthKit integration for activity and health metrics
- Weight tracking and progress visualizations
- Recipe and meal-planning workflows
- CloudKit synchronization
- Expanded unit and UI test coverage
- Accessibility and localization improvements
- Empty, loading, and error states for every major feature

## Learning project

Elyra Vita is also a practical learning project. The code is intentionally developed in understandable steps rather than hiding everything behind complex abstractions.

The goal is to learn how Swift and SwiftUI work in real application code:

- how state flows through a view hierarchy
- how reusable components are designed
- how SwiftData models are stored and queried
- how navigation and sheets are presented
- how previews support iterative UI development
- how a project can be structured for long-term maintenance

## License

This project is currently private property of Pasuki Studio. No open-source license has been granted yet.

## Author

Created by [Pasuki Studio](https://github.com/pasukistudio).
