require "yaml"
require "mini_i18n/version"
require "mini_i18n/utils"
require "mini_i18n/localization"
require "mini_i18n/pluralization"
require "mini_i18n/kernel_extensions"

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

      # Load built-in localization defaults
      @@available_locales.each do |locale|
        default_locale_path = File.join(File.dirname(__FILE__), "mini_i18n", "locales", "#{locale}.yml")
        if File.exist?(default_locale_path)
          YAML.load_file(default_locale_path).each do |loc, translations|
            add_translations(loc, translations)
          end
        end
      end
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

    def pluralization_rules
      @@pluralization_rules ||= {}
    end

    def pluralization_rules=(new_rules)
      @@pluralization_rules = new_rules
    end

    def configure
      yield(self) if block_given?
    end

    def load_translations(path)
      Dir[path.to_s].sort.each do |file|
        YAML.load_file(file).each do |locale, new_translations|
          add_translations(locale.to_s, new_translations)
        end
      end
    end

    def translate(key, options = {})
      return if key.empty? || translations.empty?

      return multiple_translate(key, options) if key.is_a?(Array)
      
      options = expand_all_locales(options)
      return multiple_locales(key, options) if options[:locale].is_a?(Array)

      _locale = available_locale?(options[:locale]) || locale
      scope = options[:scope]

      keys = [_locale.to_s]
      keys.concat(scope.to_s.split(separator)) if scope
      keys.concat(key.to_s.split(separator))

      result = lookup(*keys)

      result = with_fallbacks(result, keys)
      result = with_pluralization(result, options, _locale)
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
      locale_string = new_locale.to_s
      available_locales.include?(locale_string) && locale_string
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

    def with_pluralization(result, options, locale)
      count = options[:count]

      if count && result.is_a?(Hash)
        result = Pluralization.pluralize(result, count, locale)
      end

      result
    end

    def with_interpolation(result, options)
      if result.is_a?(String) && result.include?('%{')
        result = Utils.interpolate(result, options)
      end

      result
    end

    def multiple_translate(keys, options)
      keys.map do |key|
        t(key, options)
      end
    end

    def multiple_locales(key, options)
      options[:locale].map do |_locale|
        t(key, options.merge(locale: _locale))
      end
    end

    def expand_all_locales(options)
      if options[:locale] == '*'
        options.merge(locale: available_locales)
      else
        options
      end
    end
  end
end
