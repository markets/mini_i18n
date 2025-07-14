RSpec.describe MiniI18n do
  describe 'custom currency and distance scenarios' do
    let(:original_translations) { MiniI18n.translations.dup }
    let(:original_available_locales) { MiniI18n.available_locales.dup }

    before(:each) do
      # Store the original state
      @original_translations = MiniI18n.translations.dup
      @original_available_locales = MiniI18n.available_locales.dup
      
      # Load custom localization fixture that includes currency and distance
      MiniI18n.load_translations(File.join(File.dirname(__FILE__), 'fixtures', 'locales', 'localization.yml'))
    end

    after(:each) do
      # Restore the original state
      MiniI18n.translations.clear
      MiniI18n.translations.merge!(@original_translations)
      MiniI18n.available_locales = @original_available_locales
    end

    describe 'currency formatting' do
      it 'can format currency with custom locale data' do
        number = 1234.56
        localized_currency = MiniI18n.l(number, as: :currency, locale: :en)
        
        expect(localized_currency).to eq('1,234.56 $')
      end
    end

    describe 'distance formatting' do
      it 'can format distance with custom locale data' do
        number = 1234.56
        localized_distance = MiniI18n.l(number, as: :distance, locale: :en)
        
        expect(localized_distance).to eq('Distance: 1,234.56 miles')
      end
    end
  end
end