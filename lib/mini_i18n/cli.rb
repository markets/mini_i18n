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
      csv_file = options[:file] || 'translations.csv'
      
      unless File.exist?(csv_file)
        puts "Error: File '#{csv_file}' not found"
        exit 1
      end
      
      import_from_single_csv_with_mapping(csv_file)
    end

    def export_command
      options = parse_export_options
      output_file = options[:file] || 'translations.csv'
      
      # Always use single-file export with file path mapping
      translation_files = find_translation_files
      if translation_files.empty?
        puts "Error: No translation files found"
        exit 1
      end
      
      export_all_to_single_csv(translation_files, output_file)
      puts "Translations exported successfully to #{output_file}"
      puts "File contains #{translation_files.count} source files with file path mapping"
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
          import [--file=FILE]     Import translations from CSV file
          export [--file=FILE]     Export translations to CSV file
          version                  Show version
          help                     Show this help message

        Export/Import Workflow:
          1. Run 'mi18n export' to create a single CSV file from all YAML translation files
          2. Send CSV file to translators for translation/review
          3. Run 'mi18n import' to update original YAML files with translated content

        Key Features:
          - Single CSV file contains all translations with file path mapping
          - Keys are formatted as 'translation.key__path/to/file.yml' for easy identification
          - Import automatically restores translations to their original YAML files
          - Preserves original file structure and organization

        Examples:
          mi18n stats
          mi18n missing --locale=es
          mi18n export                    # Creates translations.csv with all translations
          mi18n export --file=custom.csv  # Creates custom.csv with all translations  
          mi18n import                    # Updates YAML files from translations.csv
          mi18n import --file=custom.csv  # Updates YAML files from custom.csv
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
        opts.on('--file=FILE', 'CSV file to import from (default: translations.csv)') do |file|
          options[:file] = file
        end
      end.parse!(@args[1..-1])
      options
    end

    def parse_export_options
      options = {}
      OptionParser.new do |opts|
        opts.on('--file=FILE', 'CSV file to export to (default: translations.csv)') do |file|
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

    def export_all_to_single_csv(translation_files, output_file)
      # Collect all keys with their source file paths
      all_key_file_pairs = []
      all_locales = Set.new
      
      translation_files.each do |yaml_file|
        yaml_content = YAML.load_file(yaml_file)
        
        # Add all locales from this file
        yaml_content.keys.each { |locale| all_locales << locale }
        
        # Collect keys with file path mapping
        yaml_content.each do |locale, translations|
          collect_keys_recursive(translations).each do |key|
            # Create mapped key: original_key__file_path
            mapped_key = "#{key}__#{yaml_file}"
            all_key_file_pairs << [mapped_key, key, yaml_file, yaml_content]
          end
        end
      end
      
      # Remove duplicates and sort
      all_key_file_pairs = all_key_file_pairs.uniq { |item| item[0] }.sort_by { |item| item[0] }
      locales = all_locales.to_a.sort
      
      # Write CSV
      CSV.open(output_file, 'w') do |csv|
        csv << ['key'] + locales
        
        all_key_file_pairs.each do |mapped_key, original_key, yaml_file, yaml_content|
          row = [mapped_key]
          
          locales.each do |locale|
            if yaml_content.key?(locale)
              value = get_nested_value(yaml_content[locale], original_key) || ''
            else
              value = ''
            end
            row << value
          end
          
          csv << row
        end
      end
    end

    def import_from_single_csv_with_mapping(csv_file)
      # Group translations by source file, but only include keys that originally belonged to that file
      translations_by_file = {}
      
      CSV.foreach(csv_file, headers: true) do |row|
        mapped_key = row['key']
        next if mapped_key.nil? || mapped_key.strip.empty?
        
        # Parse the mapped key to extract original key and file path
        if mapped_key.include?('__')
          original_key, file_path = mapped_key.split('__', 2)
        else
          # Fallback for keys without file mapping (backward compatibility)
          original_key = mapped_key
          file_path = nil
        end
        
        # Skip if we can't determine the file path
        next if file_path.nil?
        
        # Initialize file structure if needed
        translations_by_file[file_path] ||= {}
        
        # Load the original file to determine which locales it contained
        if File.exist?(file_path)
          original_content = YAML.load_file(file_path)
          original_locales = original_content.keys
        else
          # If file doesn't exist, we'll take all locales from CSV
          original_locales = row.headers.reject { |h| h == 'key' }
        end
        
        # Process each locale column, but only for locales that were in the original file
        row.headers.each do |header|
          next if header == 'key'
          
          locale = header.to_s
          value = row[header]
          
          # Skip this locale if it wasn't in the original file
          next unless original_locales.include?(locale)
          
          # Skip nil values, but allow empty strings
          next if value.nil?
          
          translations_by_file[file_path][locale] ||= {}
          set_nested_key(translations_by_file[file_path][locale], original_key, value)
        end
      end
      
      # Update each source file
      updated_files = []
      translations_by_file.each do |file_path, locale_data|
        # Load existing YAML content or create new
        yaml_content = File.exist?(file_path) ? YAML.load_file(file_path) : {}
        
        # Merge new translations
        locale_data.each do |locale, translations|
          yaml_content[locale] ||= {}
          merge_translations(yaml_content[locale], translations)
        end
        
        # Write back to file
        File.write(file_path, yaml_content.to_yaml)
        updated_files << file_path
      end
      
      if updated_files.any?
        puts "Updated #{updated_files.count} translation files:"
        updated_files.each { |file| puts "  #{file}" }
      else
        puts "No files were updated (no valid file mappings found in CSV)"
      end
    end

    def merge_translations(target, source)
      source.each do |key, value|
        if value.is_a?(Hash) && target[key].is_a?(Hash)
          merge_translations(target[key], value)
        else
          target[key] = value
        end
      end
    end
  end
end