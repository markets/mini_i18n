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
    
    context 'with export command' do
      let(:temp_csv) { File.join(temp_dir, 'test_export.csv') }
      let(:args) { ['export', "--file=#{temp_csv}"] }
      
      it 'exports translations to CSV' do
        output = capture_stdout { cli.run }
        
        expect(output).to include("Translations exported successfully to #{temp_csv}")
        expect(File.exist?(temp_csv)).to be true
        
        csv_content = CSV.read(temp_csv, headers: true)
        expect(csv_content.headers).to eq(['key', 'en', 'es'])
        expect(csv_content.map(&:to_h)).to include(
          { 'key' => 'hello', 'en' => 'Hello', 'es' => 'Hola' }
        )
      end
    end
    
    context 'with import command' do
      let(:temp_csv) { File.join(temp_dir, 'test_import.csv') }
      let(:args) { ['import', "--file=#{temp_csv}"] }
      
      before do
        # Create a CSV file to import
        CSV.open(temp_csv, 'w') do |csv|
          csv << ['key', 'en', 'es']
          csv << ['hello', 'Hello', 'Hola']
          csv << ['goodbye', 'Goodbye', 'Adiós']
        end
      end
      
      it 'imports translations from CSV' do
        output = capture_stdout { cli.run }
        
        expect(output).to include("Translations imported successfully from #{temp_csv}")
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