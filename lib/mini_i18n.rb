require "yaml"
require "mini_i18n/version"
require "mini_i18n/utils"

module MiniI18n
  class << self
    DEFAULT_LOCALE = :en
    SEPARATOR = '.'
    PLURALIZATION_COUNT_TO_KEYWORD = {
      0 => 'zero',
      1 => 'one',
      2 => 'many'
    }

    attr_accessor :fallbacks

    def default_locale
      @@default_locale ||= DEFAULT_LOCALE
    end

    def default_locale=(new_locale)
      @@default_locale = available_locale?(new_locale) || default_locale
    end

    def default_available_locales
      @@default_available_locales ||= translations.keys
    end

    def available_locales
      @@available_locales ||= default_available_locales
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

    def configure
      yield(self) if block_given?
    end

    def load_translations(path)
      Dir[path.to_s].each do |file|
        YAML.load_file(file).each do |locale, new_translations|
          locale = locale.to_s
          @@available_locales << locale unless available_locale?(locale)

          if translations[locale]
            translations[locale] = Utils.deep_merge(translations[locale], new_translations)
          else
            translations[locale] = new_translations
          end
        end
      end
    end

    def translate(key, options = {})
      return if key.empty? || translations.empty?

      _locale = available_locale?(options[:locale]) || locale
      scope = options[:scope]
      count = options[:count]

      keys = [_locale.to_s]
      keys << scope.to_s.split(SEPARATOR) if scope
      keys << key.to_s.split(SEPARATOR)
      keys = keys.flatten

      result = lookup(*keys)

      if fallbacks && result.empty?
        keys[0] = default_locale.to_s
        result = lookup(*keys)
      end

      if count && result.is_a?(Hash)
        result = result.fetch(PLURALIZATION_COUNT_TO_KEYWORD[count], nil)
      end

      if result.respond_to?(:match) && result.match(/%{\w+}/)
        result = Utils.interpolate(result, options)
      end

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
  end
end
