require "yaml"
require "mini_i18n/version"
require "mini_i18n/utils"
require "mini_i18n/localization"

module MiniI18n
  class << self
    include Localization

    DEFAULT_LOCALE = :en
    DEFAULT_SEPARATOR = '.'

    attr_accessor :fallbacks

    def default_locale
      @@default_locale ||= DEFAULT_LOCALE
    end

    def default_locale=(new_locale)
      @@default_locale = available_locale?(new_locale) || default_locale
    end

    def available_locales
      @@available_locales ||= translations.keys
    end

    def available_locales=(new_locales)
      @@available_locales = Array(new_locales).map(&:to_s)
    end

    def translations
      @@translations ||= {}
    end

    def locale
      Thread.current[:mini_i18n_locale] ||= default_locale
    end

    def locale=(new_locale)
      set_locale(new_locale)
    end

    def separator
      @@separator ||= DEFAULT_SEPARATOR
    end

    def separator=(new_separator)
      @@separator = new_separator || DEFAULT_SEPARATOR
    end

    def configure
      yield(self) if block_given?
    end

    def load_translations(path)
      Dir[path.to_s].each do |file|
        YAML.load_file(file).each do |locale, new_translations|
          add_translations(locale.to_s, new_translations)
        end
      end
    end

    def translate(key, options = {})
      return if key.empty? || translations.empty?

      _locale = available_locale?(options[:locale]) || locale
      scope = options[:scope]

      keys = [_locale.to_s]
      keys << scope.to_s.split(separator) if scope
      keys << key.to_s.split(separator)
      keys = keys.flatten

      result = lookup(*keys)

      result = with_fallbacks(result, keys)
      result = with_pluralization(result, options)
      result = with_interpolation(result, options)

      result || options[:default]
    end
    alias t translate

    private

    def set_locale(new_locale)
      new_locale = new_locale.to_s

      if available_locale?(new_locale)
        Thread.current[:mini_i18n_locale] = new_locale
      end

      locale
    end

    def available_locale?(new_locale)
      new_locale = new_locale.to_s
      available_locales.include?(new_locale) && new_locale
    end

    def lookup(*keys)
      translations.dig(*keys)
    end

    def add_translations(locale, new_translations)
      @@available_locales << locale unless available_locale?(locale)

      if translations[locale]
        translations[locale] = Utils.deep_merge(translations[locale], new_translations)
      else
        translations[locale] = new_translations
      end
    end

    def with_fallbacks(result, keys)
      if fallbacks && result.empty?
        keys[0] = default_locale.to_s
        result = lookup(*keys)
      end

      result
    end

    def with_pluralization(result, options)
      count = options[:count]

      if count && result.is_a?(Hash)
        case count
        when 0
          result = result["zero"]
        when 1
          result = result["one"]
        else
          result = result["many"]
        end
      end

      result
    end

    def with_interpolation(result, options)
      if result.respond_to?(:match) && result.match(/%{\w+}/)
        result = Utils.interpolate(result, options)
      end

      result
    end
  end
end
