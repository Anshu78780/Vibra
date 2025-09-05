# Contributing to Vibra Music App

We love your input! We want to make contributing to Vibra as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Requests

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License

In short, when you submit code changes, your submissions are understood to be under the same [MIT License](LICENSE) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using GitHub's [issue tracker](https://github.com/Anshu78780/Vibra/issues)

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/Anshu78780/Vibra/issues/new).

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Development Guidelines

### Code Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter format` to format your code
- Run `flutter analyze` to check for issues

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

### Flutter Development

- Test your changes on both Android and iOS if possible
- Ensure your code works on different screen sizes
- Follow Material Design principles
- Keep the app's dark theme consistent

### Adding New Features

1. **Create an issue** first to discuss the feature
2. **Follow the existing architecture**:
   - UI components in `lib/components/`
   - Business logic in `lib/controllers/`
   - Data models in `lib/models/`
   - Services in `lib/services/`
3. **Maintain consistency** with existing code style
4. **Update documentation** as needed

### Dependencies

- Minimize new dependencies
- Only add well-maintained packages
- Update `pubspec.yaml` description if needed

## Testing

- Write tests for new functionality
- Ensure existing tests pass
- Test on multiple devices/screen sizes
- Verify dark theme consistency

## Documentation

- Update README.md for significant changes
- Add inline code comments for complex logic
- Update API documentation if applicable

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

## Questions?

Feel free to contact the project maintainers or open an issue for discussion.

Thank you for contributing to Vibra! 🎵
