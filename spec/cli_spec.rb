require 'mini_i18n/cli'
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
    
    context 'with unused command' do
      let(:args) { ['unused'] }
      
      before do
        # Create some Ruby files that use translation keys
        FileUtils.mkdir_p('app/controllers')
        FileUtils.mkdir_p('app/views')
        
        # Create Ruby file using some keys
        File.write('app/controllers/test_controller.rb', <<~RUBY)
          class TestController
            def index
              @message = T(:hello)
              @greeting = MiniI18n.t('nested.greeting')
            end
          end
        RUBY
        
        # Create ERB file using some keys  
        File.write('app/views/test.html.erb', <<~ERB)
          <h1><%= T(:hello) %></h1>
          <p><%= T('used_key') %></p>
        ERB
        
        # Add more keys to translations so we have unused ones
        en_with_unused = {
          'en' => {
            'hello' => 'Hello',
            'nested' => { 'greeting' => 'Good morning' },
            'unused_key' => 'This key is not used',
            'another_unused' => 'This is also unused'
          }
        }
        
        es_with_unused = {
          'es' => {
            'hello' => 'Hola', 
            'nested' => { 'greeting' => '' },
            'unused_key' => 'Esta clave no se usa',
            'another_unused' => 'Esto tampoco se usa'
          }
        }
        
        File.write('locales/en.yml', en_with_unused.to_yaml)
        File.write('locales/es.yml', es_with_unused.to_yaml)
      end
      
      it 'shows unused translation keys' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Unused translation keys:')
        expect(output).to include('another_unused')
        expect(output).to include('unused_key')
        expect(output).to include('Total unused keys: 2')
        expect(output).not_to include('hello') # This key is used
        expect(output).not_to include('nested.greeting') # This key is used
      end
    end
    
    context 'with unused command with custom paths' do
      let(:args) { ['unused', '--paths=app/**/*.rb'] }
      
      before do
        # Create Ruby file that uses a key
        FileUtils.mkdir_p('app')
        File.write('app/test.rb', <<~RUBY)
          puts T(:hello)
        RUBY
        
        # Create another file outside the specified path that uses a key
        FileUtils.mkdir_p('lib')
        File.write('lib/test.rb', <<~RUBY)
          puts T('nested.greeting')
        RUBY
        
        # Add unused key to translations
        en_with_unused = {
          'en' => {
            'hello' => 'Hello',
            'nested' => { 'greeting' => 'Good morning' },
            'unused_in_lib' => 'This key is only used in lib'
          }
        }
        
        File.write('locales/en.yml', en_with_unused.to_yaml)
      end
      
      it 'scans only specified paths and shows unused keys' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('Unused translation keys:')
        # Since we only scan app/**/*.rb, nested.greeting should appear unused
        # because it's only used in lib/test.rb which is outside our scan path
        expect(output).to include('nested.greeting')
        expect(output).to include('unused_in_lib')
        expect(output).not_to include('hello') # This key is used in app/test.rb
      end
    end
    
    context 'with unused command when no unused keys exist' do
      let(:args) { ['unused'] }
      
      before do
        # Create Ruby files that use all available keys
        FileUtils.mkdir_p('app')
        File.write('app/test.rb', <<~RUBY)
          puts T(:hello)
          puts T('nested.greeting')
        RUBY
      end
      
      it 'shows message when no unused keys found' do
        output = capture_stdout { cli.run }
        
        expect(output).to include('No unused translation keys found')
        expect(output).not_to include('Total unused keys:')
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