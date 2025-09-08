require 'mini_i18n'
require 'optparse'
require 'csv'
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
      
      if options[:file]
        # Import from a specific CSV file
        unless File.exist?(options[:file])
          puts "Error: File '#{options[:file]}' not found"
          exit 1
        end
        import_from_csv_file(options[:file])
      else
        # Import from all CSV files in current directory
        csv_files = Dir.glob('*.csv')
        if csv_files.empty?
          puts "Error: No CSV files found in current directory"
          puts "Usage: mi18n import --file=translations.csv OR place CSV files in current directory"
          exit 1
        end
        
        csv_files.each { |file| import_from_csv_file(file) }
        puts "Imported translations from #{csv_files.count} CSV files: #{csv_files.join(', ')}"
      end
    end

    def export_command
      options = parse_export_options
      
      if options[:file]
        # Export to a specific CSV file (legacy single-file mode)
        load_translations_for_cli
        export_to_csv(options[:file])
        puts "Translations exported successfully to #{options[:file]}"
      else
        # Export using file-based strategy (new default)
        translation_files = find_translation_files
        if translation_files.empty?
          puts "Error: No translation files found"
          exit 1
        end
        
        exported_files = []
        translation_files.each do |yaml_file|
          csv_file = File.basename(yaml_file, File.extname(yaml_file)) + '.csv'
          export_yaml_to_csv(yaml_file, csv_file)
          exported_files << csv_file
        end
        
        puts "Exported translations to #{exported_files.count} CSV files:"
        exported_files.each { |file| puts "  #{file}" }
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
          import [--file=FILE]     Import translations from CSV file(s)
          export [--file=FILE]     Export translations to CSV file(s)
          version                  Show version
          help                     Show this help message

        Export/Import Workflow:
          1. Run 'mi18n export' to create CSV files from your YAML translation files
          2. Send CSV files to translators for translation/review
          3. Run 'mi18n import' to update YAML files with translated CSV content

        Examples:
          mi18n stats
          mi18n missing --locale=es
          mi18n export                    # Creates CSV files for each YAML file
          mi18n export --file=all.csv     # Creates single CSV with all translations  
          mi18n import                    # Updates YAML files from CSV files
          mi18n import --file=all.csv     # Imports from specific CSV file
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
        opts.on('--file=FILE', 'CSV file to import from (optional - will import all CSV files if not specified)') do |file|
          options[:file] = file
        end
      end.parse!(@args[1..-1])
      options
    end

    def parse_export_options
      options = {}
      OptionParser.new do |opts|
        opts.on('--file=FILE', 'CSV file to export to (optional - will create multiple CSV files if not specified)') do |file|
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

    def find_translation_files
      possible_patterns = [
        'config/locales/*.yml',
        'config/locales/*.yaml',
        'locales/*.yml',
        'locales/*.yaml',
        'translations/*.yml',
        'translations/*.yaml'
      ]
      
      all_files = []
      possible_patterns.each do |pattern|
        all_files.concat(Dir.glob(pattern))
      end
      
      all_files.uniq
    end

    def export_yaml_to_csv(yaml_file, csv_file)
      # Load the specific YAML file
      yaml_content = YAML.load_file(yaml_file)
      
      # Extract all locales from this file
      locales = yaml_content.keys
      
      # Collect all keys from all locales in this file
      all_keys = Set.new
      yaml_content.each do |locale, translations|
        collect_keys_recursive(translations).each { |key| all_keys << key }
      end
      
      # Write CSV
      CSV.open(csv_file, 'w') do |csv|
        csv << ['key'] + locales
        
        all_keys.to_a.sort.each do |key|
          row = [key]
          locales.each do |locale|
            value = get_nested_value(yaml_content[locale], key) || ''
            row << value
          end
          csv << row
        end
      end
    end

    def import_from_csv_file(csv_file)
      # Determine corresponding YAML file
      base_name = File.basename(csv_file, '.csv')
      yaml_file = find_corresponding_yaml_file(base_name)
      
      if yaml_file
        # File-based import: update specific YAML file
        import_to_yaml_file(csv_file, yaml_file)
      else
        # Legacy import: merge into memory (for backward compatibility)
        puts "Warning: Could not find corresponding YAML file for #{csv_file}."
        puts "Importing into memory. Changes will not be persisted to files."
        load_translations_for_cli
        import_from_csv(csv_file)
      end
    end

    def import_to_yaml_file(csv_file, yaml_file)
      # Load existing YAML content or create new structure
      yaml_content = File.exist?(yaml_file) ? YAML.load_file(yaml_file) : {}
      
      # Read CSV and update YAML content
      CSV.foreach(csv_file, headers: true) do |row|
        key = row['key']
        next if key.nil? || key.strip.empty?
        
        row.headers.each do |header|
          next if header == 'key'
          
          locale = header.to_s
          value = row[header]
          
          # Skip nil values, but allow empty strings (they might be intentional)
          next if value.nil?
          
          yaml_content[locale] ||= {}
          set_nested_key(yaml_content[locale], key, value)
        end
      end
      
      # Write back to YAML file
      File.write(yaml_file, yaml_content.to_yaml)
      puts "Updated #{yaml_file} from #{csv_file}"
    end

    def find_corresponding_yaml_file(base_name)
      possible_extensions = ['.yml', '.yaml']
      possible_patterns = [
        'config/locales/',
        'locales/',
        'translations/',
        ''  # current directory
      ]
      
      possible_patterns.each do |path|
        possible_extensions.each do |ext|
          candidate = "#{path}#{base_name}#{ext}"
          return candidate if File.exist?(candidate)
        end
      end
      
      nil
    end

    def get_nested_value(hash, key_path)
      return nil unless hash.is_a?(Hash)
      
      keys = key_path.split('.')
      current = hash
      
      keys.each do |key|
        return nil unless current.is_a?(Hash) && current.key?(key)
        current = current[key]
      end
      
      current
    end
  end
end