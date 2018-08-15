# `MiniI18n`

[![Gem](https://img.shields.io/gem/v/mini_i18n.svg?style=flat-square)](https://rubygems.org/gems/mini_i18n)
[![Build Status](https://img.shields.io/travis/markets/mini_i18n.svg?style=flat-square)](https://travis-ci.org/markets/mini_i18n)
[![Maintainability](https://api.codeclimate.com/v1/badges/9d82e7151f8a5594da0f/maintainability)](https://codeclimate.com/github/markets/mini_i18n/maintainability)

> Minimalistic I18n library for Ruby

`MiniI18n` is a simple and flexible Ruby Internationalization library. It supports localization, interpolations, pluralization, fallbacks, nested keys and more.

Translations should be stored in YAML files and they will loaded in a in-memory `Hash`.

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
  # path to your translation files
  config.load_translations(__dir__ + '/translations/*.yml')

  # default locale
  config.default_locale = :en

  # available locales in your application
  config.available_locales = [:en, :es, :fr]

  # if given key is empty, defaults to the default_locale
  config.fallbacks = true
end
```

You can also use the following format:

```ruby
MiniI18n.load_translations(__dir__ + '/translations/*.yml')
MiniI18n.default_locale = :en
```

Basic example usage:

```ruby
>> MiniI18n.t(:hello)
=> "Hello"
>> MiniI18n.t(:hello, locale: :fr)
=> "Bonjour"
>> MiniI18n.locale = :fr
=> :fr
>> MiniI18n.t(:hello)
=> "Bonjour"
>> MiniI18n.t(:hellooo)
=> nil
```

The `t` method can be also used as `translate`:

```ruby
MiniI18n.translate(:hello)
```

It accepts the following options:

* `locale`

```ruby
>> MiniI18n.t(:hello, locale: :es)
=> "Hola"
```

* `scope`

```ruby
>> MiniI18n.t('application.views.welcome')
=> "Welcome"
>> MiniI18n.t('welcome', scope: 'application.views')
=> "Welcome"
```

* `default`

```ruby
>> MiniI18n.t(:hellooo, default: 'default value')
=> "default value"
```

* `count`

Read more details in the [Pluralization section](#pluralization).

```ruby
>> MiniI18n.t('notifications', count: 0)
=> "no unread notifications"
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

You should define your plurals in the following format (supported keys: `zero`, `one` and `many`):

```yaml
en:
  notifications:
    zero: 'no unread notifications'
    one: '1 unread notification'
    many: '%{count} unread notifications'
```

Then, you should call the method with the `count` option:

```ruby
>> MiniI18n.t('notifications', count: 0)
=> "no unread notifications"
>> MiniI18n.t('notifications', count: 1)
=> "1 unread notification"
>> MiniI18n.t('notifications', count: 5)
=> "5 unread notifications"
```

### Localization

#### Dates and time

It uses `strftime` under the hood.

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

#### Numbers

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

## Development

Any kind of feedback, bug report, idea or enhancement are much appreciated.

To contribute, just fork the repo, hack on it and send a pull request. Don't forget to add specs for behaviour changes and run the test suite:

    > bundle exec rspec

## License

Copyright (c) Marc Anguera. MiniI18n is released under the [MIT](LICENSE) License.