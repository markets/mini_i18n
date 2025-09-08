require 'mini_i18n'
require 'optparse'
require 'set'
require 'yaml'

module MiniI18n
  class CLI
    def initialize(args = [])
      @args = args
      @options = {}
    end

    def run
      case @args.first
      when 'stats'
        stats_command
      when 'missing'
        missing_command
      when 'unused'
        unused_command
      when 'version'
        version_command
      when 'help', nil
        help_command
      else
        puts "Unknown command: #{@args.first}"
        puts "Run 'mi18n help' for available commands"
        exit 1
      end
    end

    private

    def stats_command
      load_translations_for_cli
      
      locales = MiniI18n.available_locales
      total_keys = collect_all_keys
      
      puts "Translation Statistics:"
      puts "====================="
      puts "Number of locales: #{locales.count}"
      puts "Total unique keys: #{total_keys.count}"
      puts ""
      
      locales.each do |locale|
        translated_keys = count_translated_keys(locale, total_keys)
        completion = (translated_keys.to_f / total_keys.count * 100).round(1)
        puts "#{locale}: #{translated_keys}/#{total_keys.count} keys (#{completion}% complete)"
      end
    end

    def missing_command
      options = parse_missing_options
      load_translations_for_cli
      
      total_keys = collect_all_keys
      locales = options[:locale] ? [options[:locale]] : MiniI18n.available_locales
      
      locales.each do |locale|
        missing_keys = find_missing_keys(locale, total_keys)
        
        if missing_keys.any?
          puts "Missing keys for '#{locale}' locale:"
          missing_keys.each { |key| puts "  #{key}" }
          puts ""
        elsif locales.count == 1
          puts "No missing keys for '#{locale}' locale"
        end
      end
    end

    def unused_command
      options = parse_unused_options
      load_translations_for_cli
      
      # Find all translation keys
      all_translation_keys = collect_all_keys.to_set
      
      # Find used keys in source files
      used_keys = find_used_translation_keys(options[:paths])
      
      # Find unused keys
      unused_keys = (all_translation_keys - used_keys).to_a.sort
      
      if unused_keys.any?
        puts "Unused translation keys:"
        puts "======================"
        unused_keys.each { |key| puts "  #{key}" }
        puts ""
        puts "Total unused keys: #{unused_keys.count}"
      else
        puts "No unused translation keys found"
      end
    end

    def version_command
      puts MiniI18n::VERSION
    end

    def help_command
      puts <<~HELP
        Usage: mi18n [command] [options]

        Commands:
          stats                    Show translation statistics
          missing [--locale=LOCALE] Show missing translation keys
          unused [--paths=PATHS]   Show unused translation keys
          version                  Show version
          help                     Show this help message

        Examples:
          mi18n stats
          mi18n missing --locale=es
          mi18n unused                           # Scan default paths for unused keys
          mi18n unused --paths="app/**/*.rb"     # Scan custom paths for unused keys
      HELP
    end

    def parse_missing_options
      options = {}
      OptionParser.new do |opts|
        opts.on('--locale=LOCALE', 'Filter by specific locale') do |locale|
          options[:locale] = locale
        end
      end.parse!(@args[1..-1])
      options
    end

    def parse_unused_options
      options = { paths: nil }
      OptionParser.new do |opts|
        opts.on('--paths=PATHS', 'Comma-separated glob patterns to scan (default: app/**/*.{rb,erb}, lib/**/*.rb)') do |paths|
          options[:paths] = paths.split(',').map(&:strip)
        end
      end.parse!(@args[1..-1])
      
      # Set default paths if none provided
      options[:paths] ||= [
        'app/**/*.{rb,erb}',
        'lib/**/*.rb'
      ]
      
      options
    end

    def load_translations_for_cli
      # Try to load translations from common locations
      possible_paths = [
        'config/locales/*.yml',
        'config/locales/*.yaml',
        'locales/*.yml',
        'locales/*.yaml',
        'translations/*.yml',
        'translations/*.yaml'
      ]
      
      loaded = false
      possible_paths.each do |pattern|
        files = Dir.glob(pattern)
        if files.any?
          MiniI18n.load_translations(pattern)
          loaded = true
          break
        end
      end
      
      unless loaded
        puts "Warning: No translation files found in common locations:"
        puts "  config/locales/*.yml"
        puts "  locales/*.yml"
        puts "  translations/*.yml"
        puts ""
      end
    end

    def collect_all_keys
      all_keys = Set.new
      
      MiniI18n.translations.each do |locale, translations|
        collect_keys_recursive(translations).each { |key| all_keys << key }
      end
      
      all_keys.to_a.sort
    end

    def collect_keys_recursive(hash, prefix = "")
      keys = []
      hash.each do |key, value|
        full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        
        if value.is_a?(Hash)
          keys.concat(collect_keys_recursive(value, full_key))
        else
          keys << full_key
        end
      end
      keys
    end

    def count_translated_keys(locale, all_keys)
      all_keys.count do |key|
        value = MiniI18n.t(key, locale: locale, default: nil)
        !value.nil? && !value.to_s.strip.empty?
      end
    end

    def find_missing_keys(locale, all_keys)
      all_keys.select do |key|
        value = MiniI18n.t(key, locale: locale, default: nil)
        value.nil? || value.to_s.strip.empty?
      end
    end


    def find_used_translation_keys(paths)
      used_keys = Set.new
      
      paths.each do |pattern|
        Dir.glob(pattern).each do |file_path|
          next unless File.file?(file_path)
          
          begin
            content = File.read(file_path)
            
            # Find translation method calls with various patterns
            # T(:key), T('key'), T("key")
            content.scan(/\bT\s*\(\s*:([a-zA-Z_][a-zA-Z0-9_.]*)\s*\)/) do |match|
              used_keys << match[0]
            end
            
            content.scan(/\bT\s*\(\s*['"]([^'"]+)['"]\s*\)/) do |match|
              used_keys << match[0]
            end
            
            # MiniI18n.t(:key), MiniI18n.t('key'), MiniI18n.translate(:key)
            content.scan(/\bMiniI18n\.(?:t|translate)\s*\(\s*:([a-zA-Z_][a-zA-Z0-9_.]*)\s*\)/) do |match|
              used_keys << match[0]
            end
            
            content.scan(/\bMiniI18n\.(?:t|translate)\s*\(\s*['"]([^'"]+)['"]\s*\)/) do |match|
              used_keys << match[0]
            end
            
            # Handle scoped calls like T('key', scope: 'scope')
            content.scan(/\bT\s*\(\s*['"]([^'"]+)['"]\s*,\s*scope:\s*['"]([^'"]+)['"]/) do |key, scope|
              used_keys << "#{scope}.#{key}"
            end
            
          rescue => e
            # Skip files that can't be read (binary files, etc.)
            next
          end
        end
      end
      
      used_keys
    end


  end
end