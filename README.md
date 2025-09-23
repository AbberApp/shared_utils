# shared_utils

A Flutter/Dart package that contains shared utilities and helper classes used across multiple projects.  
It helps reduce code duplication by centralizing common logic such as:

- File management (save, read, delete files)
- Connection status monitoring (online/offline detection)
- General utilities (formatting, string helpers, etc.)

## Features
- Easy to integrate into any Flutter or Dart project
- Keeps your codebase clean and consistent
- Works as a local package (via `path`) or as a remote dependency (via Git)

## Installation
Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  shared_utils:
    git:
      url: https://github.com/your-username/shared_utils.git
      ref: main
