# MiniI18n

[![Gem](https://img.shields.io/gem/v/mini_i18n.svg?style=flat-square)](https://rubygems.org/gems/mini_i18n)
[![Build Status](https://img.shields.io/travis/markets/mini_i18n.svg?style=flat-square)](https://travis-ci.org/markets/mini_i18n)

> Minimalistic I18n library for Ruby

`MiniI18n` is a simple and flexible Ruby Internationalization library. It supports interpolations, fallbacks, nested keys and more.

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

It also accepts interpolation:

```ruby
>> MiniI18n.t(:hello_with_name, name: 'John Doe')
=> "Hello John Doe"
```

## Development

Any kind of feedback, bug report, idea or enhancement are much appreciated.

To contribute, just fork the repo, hack on it and send a pull request. Don't forget to add specs for behaviour changes and run the test suite:

    > bundle exec rspec

## License

Copyright (c) Marc Anguera. MiniI18n is released under the [MIT](LICENSE) License.