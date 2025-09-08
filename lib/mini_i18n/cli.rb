require 'mini_i18n'
require 'optparse'
require 'csv'
require 'set'

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
      when 'import'
        import_command
      when 'export'
        export_command
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

    def import_command
      options = parse_import_options
      
      unless options[:file]
        puts "Error: --file option is required"
        puts "Usage: mi18n import --file=translations.csv"
        exit 1
      end
      
      unless File.exist?(options[:file])
        puts "Error: File '#{options[:file]}' not found"
        exit 1
      end
      
      # Load existing translations first
      load_translations_for_cli
      
      import_from_csv(options[:file])
      puts "Translations imported successfully from #{options[:file]}"
      puts "Note: Imported translations are merged with existing ones in memory."
      puts "To persist changes, use 'mi18n export' to save to files."
    end

    def export_command
      options = parse_export_options
      load_translations_for_cli
      
      output_file = options[:file] || 'translations.csv'
      export_to_csv(output_file)
      puts "Translations exported successfully to #{output_file}"
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
          import --file=FILE       Import translations from CSV file
          export [--file=FILE]     Export translations to CSV file (default: translations.csv)
          version                  Show version
          help                     Show this help message

        Examples:
          mi18n stats
          mi18n missing --locale=es
          mi18n import --file=translations.csv
          mi18n export --file=my_translations.csv
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

    def parse_import_options
      options = {}
      OptionParser.new do |opts|
        opts.on('--file=FILE', 'CSV file to import from') do |file|
          options[:file] = file
        end
      end.parse!(@args[1..-1])
      options
    end

    def parse_export_options
      options = {}
      OptionParser.new do |opts|
        opts.on('--file=FILE', 'CSV file to export to') do |file|
          options[:file] = file
        end
      end.parse!(@args[1..-1])
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

    def import_from_csv(file_path)
      translations_by_locale = {}
      
      CSV.foreach(file_path, headers: true) do |row|
        key = row['key']
        next if key.nil? || key.strip.empty?
        
        row.headers.each do |header|
          next if header == 'key' || row[header].nil?
          
          locale = header.to_s
          value = row[header].to_s
          
          next if value.strip.empty?
          
          translations_by_locale[locale] ||= {}
          set_nested_key(translations_by_locale[locale], key, value)
        end
      end
      
      # Load the imported translations
      translations_by_locale.each do |locale, translations|
        MiniI18n.send(:add_translations, locale, translations)
      end
    end

    def export_to_csv(file_path)
      all_keys = collect_all_keys
      locales = MiniI18n.available_locales
      
      CSV.open(file_path, 'w') do |csv|
        # Write header
        csv << ['key'] + locales
        
        # Write data
        all_keys.each do |key|
          row = [key]
          locales.each do |locale|
            value = MiniI18n.t(key, locale: locale, default: '')
            row << value
          end
          csv << row
        end
      end
    end

    def set_nested_key(hash, key_path, value)
      keys = key_path.split('.')
      current = hash
      
      keys[0..-2].each do |key|
        current[key] ||= {}
        current = current[key]
      end
      
      current[keys.last] = value
    end
  end
end