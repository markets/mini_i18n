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
      
      import_from_single_csv(csv_file)
    end

    def export_command
      options = parse_export_options
      output_file = options[:file] || 'translations.csv'
      
      translation_files = find_translation_files
      if translation_files.empty?
        puts "Error: No translation files found"
        exit 1
      end
      
      export_to_single_csv(translation_files, output_file)
      puts "Translations exported successfully to #{output_file}"
      puts "File contains all translations from #{translation_files.count} source files"
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
          - Single CSV file contains all translations with clean, readable keys
          - Import automatically finds and updates the correct YAML files
          - Preserves original file structure and organization
          - Clean translation keys without file path information

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

    def export_to_single_csv(translation_files, output_file)
      # Collect all unique keys across all files
      all_keys = Set.new
      all_locales = Set.new
      file_contents = {}
      
      translation_files.each do |yaml_file|
        yaml_content = YAML.load_file(yaml_file)
        file_contents[yaml_file] = yaml_content
        
        # Add all locales from this file
        yaml_content.keys.each { |locale| all_locales << locale }
        
        # Collect all unique keys from this file
        yaml_content.each do |locale, translations|
          collect_keys_recursive(translations).each do |key|
            all_keys << key
          end
        end
      end
      
      # Sort keys and locales for consistent output
      sorted_keys = all_keys.to_a.sort
      locales = all_locales.to_a.sort
      
      # Write CSV with clean keys (no file path mapping)
      CSV.open(output_file, 'w') do |csv|
        csv << ['key'] + locales
        
        sorted_keys.each do |key|
          row = [key]
          
          locales.each do |locale|
            # Find the value for this key in any file that contains this locale
            value = ''
            translation_files.each do |yaml_file|
              yaml_content = file_contents[yaml_file]
              if yaml_content.key?(locale)
                found_value = get_nested_value(yaml_content[locale], key)
                if found_value && !found_value.to_s.strip.empty?
                  value = found_value
                  break  # Use the first non-empty value found
                end
              end
            end
            row << value
          end
          
          csv << row
        end
      end
    end

    def import_from_single_csv(csv_file)
      # Load all existing YAML files to understand their structure
      translation_files = find_translation_files
      if translation_files.empty?
        puts "Error: No translation files found to update"
        return
      end
      
      # Load content of all files
      file_contents = {}
      translation_files.each do |yaml_file|
        file_contents[yaml_file] = File.exist?(yaml_file) ? YAML.load_file(yaml_file) : {}
      end
      
      # Process CSV and update files
      updated_files = Set.new
      
      CSV.foreach(csv_file, headers: true) do |row|
        key = row['key']
        next if key.nil? || key.strip.empty?
        
        # Process each locale column
        row.headers.each do |header|
          next if header == 'key'
          
          locale = header.to_s
          value = row[header]
          
          # Skip nil values, but allow empty strings
          next if value.nil?
          
          # Find which files should contain this key for this locale
          files_to_update = find_files_containing_key(key, locale, file_contents)
          
          # If no files contain this key+locale combination, try to find a suitable file
          if files_to_update.empty?
            files_to_update = find_suitable_files_for_locale(locale, file_contents)
          end
          
          # Update the key in all relevant files
          files_to_update.each do |yaml_file|
            file_contents[yaml_file][locale] ||= {}
            set_nested_key(file_contents[yaml_file][locale], key, value)
            updated_files << yaml_file
          end
        end
      end
      
      # Write back all updated files
      updated_files.each do |file_path|
        File.write(file_path, file_contents[file_path].to_yaml)
      end
      
      if updated_files.any?
        puts "Updated #{updated_files.count} translation files:"
        updated_files.each { |file| puts "  #{file}" }
      else
        puts "No files were updated"
      end
    end
    
    def find_files_containing_key(key, locale, file_contents)
      matching_files = []
      
      file_contents.each do |file_path, yaml_content|
        if yaml_content.key?(locale)
          # Check if this file contains the key (even if the value is empty)
          existing_value = get_nested_value(yaml_content[locale], key)
          if !existing_value.nil?
            matching_files << file_path
          end
        end
      end
      
      matching_files
    end
    
    def find_suitable_files_for_locale(locale, file_contents)
      # Find files that contain this locale
      suitable_files = []
      
      file_contents.each do |file_path, yaml_content|
        if yaml_content.key?(locale)
          suitable_files << file_path
        end
      end
      
      # If no files contain this locale, use the first file (or create structure)
      if suitable_files.empty? && !file_contents.empty?
        suitable_files = [file_contents.keys.first]
      end
      
      suitable_files
    end


  end
end