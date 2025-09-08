require 'mini_i18n'
require 'mini_i18n/cli'
require 'csv'
require 'tempfile'
require 'fileutils'
require 'yaml'
require 'stringio'

RSpec.describe MiniI18n::CLI do
  let(:cli) { described_class.new(args) }
  
  describe '#run' do
    context 'with version command' do
      let(:args) { ['version'] }
      
      it 'prints the version' do
        expect { cli.run }.to output("#{MiniI18n::VERSION}\n").to_stdout
      end
    end
    
    context 'with help command' do
      let(:args) { ['help'] }
      
      it 'prints help information' do
        expect { cli.run }.to output(/Usage: mi18n/).to_stdout
      end
    end
    
    context 'with no arguments' do
      let(:args) { [] }
      
      it 'prints help information' do
        expect { cli.run }.to output(/Usage: mi18n/).to_stdout
      end
    end
    
    context 'with unknown command' do
      let(:args) { ['unknown'] }
      
      it 'prints error and exits' do
        expect { 
          begin
            cli.run
          rescue SystemExit
            # Capture the SystemExit
          end
        }.to output(/Unknown command: unknown/).to_stdout
      end
    end
  end
  
  describe 'with translation files' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:original_dir) { Dir.pwd }
    
    before do
      # Change to temp directory so CLI can find files
      Dir.chdir(temp_dir)
      
      # Create locales directory
      FileUtils.mkdir_p('locales')
      
      # Create test translation files
      en_content = {
        'en' => {
          'hello' => 'Hello',
          'nested' => { 'greeting' => 'Good morning' }
        }
      }
      
      es_content = {
        'es' => {
          'hello' => 'Hola',
          'nested' => { 'greeting' => '' }
        }
      }
      
      File.write('locales/en.yml', en_content.to_yaml)
      File.write('locales/es.yml', es_content.to_yaml)
    end
    
    after do
      Dir.chdir(original_dir)
      FileUtils.rm_rf(temp_dir)
    end
    
    context 'with stats command' do
      let(:args) { ['stats'] }
      
      it 'shows translation statistics' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Translation Statistics:')
        expect(output).to include('Number of locales: 2')
        expect(output).to include('Total unique keys: 2')
        expect(output).to include('en: 2/2 keys (100.0% complete)')
        expect(output).to include('es: 1/2 keys (50.0% complete)')
      end
    end
    
    context 'with missing command' do
      let(:args) { ['missing'] }
      
      it 'shows missing translation keys' do
        output = capture_stdout { cli.run }
        
        expect(output).to include("Missing keys for 'es' locale:")
        expect(output).to include('nested.greeting')
      end
    end
    
    context 'with missing command and locale filter' do
      let(:args) { ['missing', '--locale=es'] }
      
      it 'shows missing keys for specific locale' do
        output = capture_stdout { cli.run }
        
        expect(output).to include("Missing keys for 'es' locale:")
        expect(output).to include('nested.greeting')
        expect(output).not_to include("Missing keys for 'en' locale:")
      end
    end
    
    context 'with export command (single-file strategy with clean keys)' do
      let(:args) { ['export'] }
      
      it 'exports translations to single CSV file with clean keys' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Translations exported successfully to translations.csv')
        expect(output).to include('File contains all translations from 2 source files')
        expect(File.exist?('translations.csv')).to be true
        
        csv_content = CSV.read('translations.csv', headers: true)
        expect(csv_content.headers).to eq(['key', 'en', 'es'])
        
        # Check that keys are clean (no file path mapping)
        keys = csv_content.map { |row| row['key'] }
        expect(keys).to include('hello')
        expect(keys).to include('nested.greeting')
        expect(keys).not_to include('hello__locales/en.yml')
        expect(keys).not_to include('hello__locales/es.yml')
        
        # Check that values are correctly populated
        hello_row = csv_content.find { |row| row['key'] == 'hello' }
        expect(hello_row['en']).to eq('Hello')
        expect(hello_row['es']).to eq('Hola')
        
        greeting_row = csv_content.find { |row| row['key'] == 'nested.greeting' }
        expect(greeting_row['en']).to eq('Good morning')
        expect(greeting_row['es']).to eq('')
      end
    end
    
    context 'with export command with custom file' do
      let(:temp_csv) { File.join(temp_dir, 'custom_export.csv') }
      let(:args) { ['export', "--file=#{temp_csv}"] }
      
      it 'exports translations to specified CSV file' do
        output = capture_stdout { cli.run }
        
        expect(output).to include("Translations exported successfully to #{temp_csv}")
        expect(File.exist?(temp_csv)).to be true
        
        csv_content = CSV.read(temp_csv, headers: true)
        expect(csv_content.headers).to eq(['key', 'en', 'es'])
        
        # Check clean keys (no file path mapping)
        keys = csv_content.map { |row| row['key'] }
        expect(keys).to include('hello')
        expect(keys).to include('nested.greeting')
        expect(keys).not_to include('hello__locales/en.yml')
      end
    end
    
    context 'with import command (single-file strategy with clean keys)' do
      let(:args) { ['import'] }
      
      before do
        # Create CSV file with clean keys (no file path mapping)
        CSV.open('translations.csv', 'w') do |csv|
          csv << ['key', 'en', 'es']
          csv << ['hello', 'Hello Updated', 'Hola Actualizado']
          csv << ['nested.greeting', 'Good morning Updated', 'Buenos días actualizados']
          csv << ['new_key', 'New Value', 'Nuevo Valor']
        end
      end
      
      it 'imports translations from CSV file and updates original YAML files' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Updated 2 translation files:')
        expect(output).to include('locales/en.yml')
        expect(output).to include('locales/es.yml')
        
        # Check that YAML files were updated correctly
        en_content = YAML.load_file('locales/en.yml')
        expect(en_content['en']['hello']).to eq('Hello Updated')
        expect(en_content['en']['nested']['greeting']).to eq('Good morning Updated')
        expect(en_content['en']['new_key']).to eq('New Value')
        
        es_content = YAML.load_file('locales/es.yml')
        expect(es_content['es']['hello']).to eq('Hola Actualizado')
        expect(es_content['es']['nested']['greeting']).to eq('Buenos días actualizados')
        expect(es_content['es']['new_key']).to eq('Nuevo Valor')
      end
    end
    
    context 'with import command with custom file' do
      let(:temp_csv) { File.join(temp_dir, 'custom_import.csv') }
      let(:args) { ['import', "--file=#{temp_csv}"] }
      
      before do
        # Create a CSV file with clean keys (no file path mapping)
        CSV.open(temp_csv, 'w') do |csv|
          csv << ['key', 'en', 'es']
          csv << ['hello', 'Custom Hello', 'Hola Personalizado']
          csv << ['new_key', 'New Value', 'Nuevo Valor']
        end
      end
      
      it 'imports translations from custom CSV file' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Updated 2 translation files:')
        expect(output).to include('locales/en.yml')
        expect(output).to include('locales/es.yml')
        
        # Check that YAML files were updated
        en_content = YAML.load_file('locales/en.yml')
        expect(en_content['en']['hello']).to eq('Custom Hello')
        expect(en_content['en']['new_key']).to eq('New Value')
        
        es_content = YAML.load_file('locales/es.yml')
        expect(es_content['es']['hello']).to eq('Hola Personalizado')
        expect(es_content['es']['new_key']).to eq('Nuevo Valor')
      end
    end
  end
  
  private
  
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end