# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0]

- Add more languages support for localization: Russian (ru) and Arabic (ar)
- Add multiple objects and multiple locales support to localize method
- Performance optimizations
- Add support for `locale: '*'` to use all available locales

## [1.0.0]

- Add global shortcuts `T()` and `L()` convenience methods
- Add built-in localization defaults for common languages

## [0.9.0]

- Move from Travis CI to GitHub Actions
- Remove official support for old Rubies (2.3 and 2.4)
- Force `MiniI18n.load_translations` to load files in alphabetical order

## [0.8.0]

- Custom pluralization rules
- Define required Ruby version in `gemspec`

## [0.7.0]

- Allow multiple translations by keys and locales

## [0.6.0]

- Allow to customize separator for nested keys

## [0.5.0]

- Localization support for dates, time and numbers

## [0.4.0]

- Pluralization support

## [0.3.1]

- Avoid `MiniI18n.load_translations` to raise an exception when a nil path is passed

## [0.3.0]

- Improves `MiniI18n.available_locales=` method to always wrap arguments into an Array

## [0.2.1]

- Define `homepage` in `gemspec`

## [0.2.0]

- Add docs!
- Fixes `MiniI18n.default_locale=` method

## 0.1.0

- First release :tada:

[1.1.0]: https://github.com/markets/mini_i18n/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/markets/mini_i18n/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/markets/mini_i18n/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/markets/mini_i18n/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/markets/mini_i18n/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/markets/mini_i18n/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/markets/mini_i18n/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/markets/mini_i18n/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/markets/mini_i18n/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/markets/mini_i18n/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/markets/mini_i18n/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/markets/mini_i18n/compare/v0.1.0...v0.2.0
