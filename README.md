# `MiniI18n`

[![Gem](https://img.shields.io/gem/v/mini_i18n.svg?style=flat-square)](https://rubygems.org/gems/mini_i18n)
[![Build Status](https://github.com/markets/mini_i18n/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/markets/mini_i18n/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/9d82e7151f8a5594da0f/maintainability)](https://codeclimate.com/github/markets/mini_i18n/maintainability)

> Minimalistic i18n library for Ruby

`MiniI18n` is a simple, flexible, and fast Ruby Internationalization library. It supports localization, interpolation, pluralization, fallbacks, nested keys and more, with a minimal footprint and straightforward API (inspired by the well-known [I18n gem](https://github.com/ruby-i18n/i18n)).

Translations should be stored in `YAML` or `JSON` files and they will be loaded in an in-memory `Hash`.

```yaml
en:
  hello: 'Hello'
```

```ruby
>> T(:hello)
=> "Hello"
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mini_i18n'
```

And then execute:

    bundle install

Or install it yourself as:

    gem install mini_i18n

## Configuration

Configure your environment using the `configure` method:

```ruby
MiniI18n.configure do |config|
  # Path to your translation files.
  config.load_translations(__dir__ + '/translations/*')

  # Default locale.
  config.default_locale = :pt

  # Available locales in your application.
  config.available_locales = [:en, :es, :fr, :pt]

  # If given key is empty, defaults to the default_locale.
  config.fallbacks = true

  # Custom separator for nested keys.
  config.separator = '/'

  # Custom pluralization rules, by locale.
  config.pluralization_rules = {
    es: -> (n) { n == 0 ? 'zero' : 'other' },
    fr: -> (n) { ... }
  }
end
```

Alternatively, you can also use this format:

```ruby
MiniI18n.load_translations(__dir__ + '/translations/*')
MiniI18n.default_locale = :en
MiniI18n.available_locales = [:en, :es, :fr, :pt]
```

## Usage

**Quick examples:**

```ruby
>> T(:hello)
=> "Hello"
>> T(:hello, locale: :fr)
=> "Bonjour"
>> MiniI18n.locale = :es
>> T(:hello)
=> "Hola"
>> T(:non_existent_key)
=> nil
>> T([:hello, :bye])
=> ["Hello", "Bye"]
>> T('application.validations.empty')
=> "Can't be empty!"
```

### Methods

- Use `T()` for translations.
- Use `L()` for localization (dates, times, numbers). Read more details [in this section](#localization).

You can also use the long form methods:
- `MiniI18n.t(:hello)` or `MiniI18n.translate(:hello)`
- `MiniI18n.l(Date.today)` or `MiniI18n.localize(Date.today)`

### Options for translations

**`locale`**

```ruby
>> T(:hello, locale: :es)
=> "Hola"
>> T(:hello, locale: [:en, :fr, :es])
=> ["Hello", "Bonjour", "Hola"]
```

**`scope`**

```ruby
>> T('application.views.welcome')
=> "Welcome"
>> T('welcome', scope: 'application.views')
=> "Welcome"
```

**`default`**

```ruby
>> T(:non_existent_key, default: 'this is a default value')
=> "this is a default value"
```

**`count`**

```ruby
>> T('notifications', count: 0)
=> "no unread notifications"
```

Read more details in the [Pluralization](#pluralization) section.

### Nested Keys

Use custom separators (default is `.`) to access nested keys.

```yaml
en:
  app:
    controllers:
      not_found: "Not found!"
```

```ruby
T('application.validations.empty')
MiniI18n.separator = '/'
T('application/validations/empty')
```

### Interpolation

```yaml
en:
  hello_with_name: "Hello %{name}!"
```

```ruby
>> T(:hello_with_name, name: 'John Doe')
=> "Hello John Doe!"
```

### Pluralization

Define plurals (default keys: `zero`, `one`, `other`):

```yaml
en:
  notifications:
    zero: 'good job! no new notifications'
    one: '1 unread notification'
    other: '%{count} unread notifications'
```

```ruby
>> T('notifications', count: 0)
=> "good job! no new notifications"
>> T('notifications', count: 1)
=> "1 unread notification"
>> T('notifications', count: 5)
=> "5 unread notifications"
```

#### Custom pluralization rules

You are also able to customize how plurals are handled, in each locale, by defining custom pluralization rules. Example:

```ruby
MiniI18n.pluralization_rules = {
  es: -> (n) {
    if n == 0
      'zero'
    elsif (1..3).include?(n)
      'few'
    elsif (4..10).include?(n)
      'many'
    else
      'other'
    end
  }
}
```

Then, define those keys in your translation files:

```yaml
es:
  notifications:
    zero: 'no tienes nuevas notificaciones'
    few: 'tienes algunas notificaciones pendientes ...'
    many: 'tienes %{count} notificaciones!'
    other: 'alerta!! %{count} notificaciones!'
```

```ruby
>> T('notifications', count: 0)
=> "no tienes nuevas notificaciones"
>> T('notifications', count: 2)
=> "tienes algunas notificaciones pendientes ..."
>> T('notifications', count: 5)
=> "tienes 5 notificaciones!"
>> T('notifications', count: 20)
=> "alerta!! 20 notificaciones!"
```

### Localization

Use `L()` to localize dates, times, and numbers. Don't forget you can also use `MiniI18n.l()` or `MiniI18n.localize()`.

`MiniI18n` provides built-in localization defaults for some languages:
- `:en` - English
- `:es` - Spanish
- `:fr` - French
- `:de` - German
- `:pt` - Portuguese
- `:it` - Italian
- `:nl` - Dutch
- `:zh` - Chinese
- `:ja` - Japanese

These defaults include proper date/time formats, day and month names, and number formatting that follows each language's conventions. You can check a full example of all necessary and useful keys [in this folder](lib/mini_i18n/locales/).

#### Dates and time

It uses `strftime` under the hood. You can customize the defaults using the following format:

```yaml
en:
  date:
    formats:
      default: "%A %d, %b %Y"
      short: "%d %B, %y"
```

```ruby
>> L(Date.new(2018, 8, 15))
=> "Wednesday 15, Aug 2018"
>> L(Date.new(2018, 8, 15), format: :short)
=> "15 August, 18"
```

#### Numbers

To localize your numbers, you can provide the following keys:

```yaml
en:
  number:
    format:
      delimiter: ','
      separator: '.'
    as:
      currency: '%{number} $'
```

```ruby
>> L(1000.25)
=> "1,000.25"
>> L(1000, as: :currency)
=> "1,000 $"
>> L(1000, as: :currency, locale: :es)
=> "1.000 €"
```

**TIP** 💡 By using the `:as` option you can build custom full sentences with formatted numbers, like:

```yaml
en:
  number:
    as:
      final_price: 'Final price: %{number} $'
      percentage: '%{number}%'
```

```ruby
>> L(1000, as: :final_price)
=> "Final price: 1,000 $"
>> L(70.5, as: :percentage)
=> "70.5%"
```

## Development

Feedback, bug reports, ideas, and enhancements are welcome!

To contribute, fork the repo, make your changes, and open a pull request. Please add specs for any behavior changes and run the test suite:

    bundle exec rspec

## License

Copyright (c) Marc Anguera. `MiniI18n` is released under the [MIT](LICENSE) License.
