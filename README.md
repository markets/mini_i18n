# `MiniI18n`

[![Gem](https://img.shields.io/gem/v/mini_i18n.svg?style=flat-square)](https://rubygems.org/gems/mini_i18n)
[![Build Status](https://github.com/markets/mini_i18n/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/markets/mini_i18n/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/9d82e7151f8a5594da0f/maintainability)](https://codeclimate.com/github/markets/mini_i18n/maintainability)

> Minimalistic I18n library for Ruby

`MiniI18n` is a simple, flexible and fast Ruby Internationalization library. It supports localization, interpolations, pluralization, fallbacks, nested keys and more.

Translations should be stored in `YAML` or `JSON` files and they will be loaded in an in-memory `Hash`.

```yaml
en:
  hello: 'Hello'
```

```ruby
>> MiniI18n.t(:hello)
=> "Hello"
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mini_i18n'
```

And then execute:

    > bundle install

Or install it yourself as:

    > gem install mini_i18n

## Usage

You should use the `configure` method to setup your environment:

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

You can also use the following format:

```ruby
MiniI18n.load_translations(__dir__ + '/translations/*')
MiniI18n.default_locale = :en
```

Examples usage:

```ruby
>> MiniI18n.t(:hello)
=> "Hello"
>> MiniI18n.t(:hello, locale: :fr)
=> "Bonjour"
>> MiniI18n.locale = :fr
=> :fr
>> MiniI18n.t(:hello)
=> "Bonjour"
>> MiniI18n.t(:non_existent_key)
=> nil
>> MiniI18n.t([:hello, :bye])
=> ["Hello", "Bye"]
>> MiniI18n.t('app.controllers.not_found')
=> "Not found!"
```

The `t()` method can be also used as `translate()`:

```ruby
MiniI18n.translate(:hello)
```

Or even using the global shortcut `T()`:

```ruby
T(:hello)
```

It accepts the following options:

* `locale`

```ruby
>> MiniI18n.t(:hello, locale: :es)
=> "Hola"
```

You can also get multiple locales at once by passing an array:

```ruby
>> MiniI18n.t(:hello, locale: [:en, :fr, :es])
=> ["Hello", "Bonjour", "Hola"]
```

* `scope`

```ruby
>> MiniI18n.t('application.views.welcome')
=> "Welcome"
>> MiniI18n.t('welcome', scope: 'application.views')
=> "Welcome"
```

Read more details about nested keys in [this section](#nested-keys).

* `default`

```ruby
>> MiniI18n.t(:non_existent_key, default: 'default value')
=> "default value"
```

* `count`

```ruby
>> MiniI18n.t('notifications', count: 0)
=> "no unread notifications"
```

Read more details in the [Pluralization](#pluralization) section.

### Nested Keys

You can use a custom separator when accessing nested keys (default separator is `.`):

```yaml
en:
  app:
    controllers:
      not_found: "Not found!"
```

```ruby
MiniI18n.t('app.controllers.not_found')
MiniI18n.separator = '/'
MiniI18n.t('app/controllers/not_found')
```

### Interpolation

You can also use variables in your translation definitions:

```yaml
en:
  hello_with_name: "Hello %{name}!"
```

```ruby
>> MiniI18n.t(:hello_with_name, name: 'John Doe')
=> "Hello John Doe!"
```

### Pluralization

You should define your plurals in the following format (default pluralization rule accepts the keys: `zero`, `one` and `other`):

```yaml
en:
  notifications:
    zero: 'good job! no new notifications'
    one: '1 unread notification'
    other: '%{count} unread notifications'
```

Then, you should call the method with the `count` option:

```ruby
>> MiniI18n.t('notifications', count: 0)
=> "good job! no new notifications"
>> MiniI18n.t('notifications', count: 1)
=> "1 unread notification"
>> MiniI18n.t('notifications', count: 5)
=> "5 unread notifications"
```

#### Custom pluralization rules

You are also able to customize how plurals are handled, by locale, defining custom pluralization rules. Example:

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

Now, in your translation files, you should define content for those keys:

```yaml
es:
  notifications:
    zero: 'no tienes nuevas notificaciones'
    few: 'tienes algunas notificaciones pendientes ...'
    many: 'tienes %{count} notificaciones!'
    other: 'alerta!! %{count} notificaciones!'
```

And then, you get:

```ruby
>> MiniI18n.t('notifications', count: 0)
=> "no tienes nuevas notificaciones"
>> MiniI18n.t('notifications', count: 2)
=> "tienes algunas notificaciones pendientes ..."
>> MiniI18n.t('notifications', count: 5)
=> "tienes 5 notificaciones!"
>> MiniI18n.t('notifications', count: 20)
=> "alerta!! 20 notificaciones!"
```

### Localization

You can also use the `MiniI18n.l()` (or the long version `MiniI18n.localize()` or the global shorcut `L()`) method to localize your dates, time and numbers.

#### Dates and time

It uses `strftime` under the hood. You should provide your localizations using the following format:

```yaml
en:
  date:
    formats:
      default: "%A %d, %B, %Y"
      short: "%d %b %y"
```

```ruby
>> MiniI18n.l(Date.new(2018, 8, 15))
=> "Wednesday 15, August, 2018"
>> MiniI18n.l(Date.new(2018, 8, 15), format: :short)
=> "15 Aug 18"
```

You can check a full example of all necessary and useful keys [in this file](spec/fixtures/locales/localization.yml).

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
>> MiniI18n.l(1000.25)
=> "1,000.25"
>> MiniI18n.l(1000, as: :currency)
=> "1,000 $"
>> MiniI18n.l(1000, as: :currency, locale: :es)
=> "1.000 €"
```

**TIP** By using the `:as` option you can build custom full sentences with formatted numbers, like:

```yaml
en:
  number:
    as:
      final_price: 'Final price: %{number} $'
      percentage: '%{number}%'
```

```ruby
>> MiniI18n.l(1000, as: :final_price)
=> "Final price: 1,000 $"
>> MiniI18n.l(70.5, as: :percentage)
=> "70.5%"
```

## Development

Any kind of feedback, bug report, idea or enhancement are much appreciated.

To contribute, just fork the repo, hack on it and send a pull request. Don't forget to add specs for behaviour changes and run the test suite:

    > bundle exec rspec

## License

Copyright (c) Marc Anguera. MiniI18n is released under the [MIT](LICENSE) License.
