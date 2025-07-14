RSpec.describe MiniI18n do
  describe 'load_default_locales' do
    let(:original_translations) { MiniI18n.translations.dup }
    let(:original_available_locales) { MiniI18n.available_locales.dup }

    before(:each) do
      # Store the original state
      @original_translations = MiniI18n.translations.dup
      @original_available_locales = MiniI18n.available_locales.dup
    end

    after(:each) do
      # Restore the original state
      MiniI18n.translations.clear
      MiniI18n.translations.merge!(@original_translations)
      MiniI18n.available_locales = @original_available_locales
    end

    it 'loads Spanish locale defaults' do
      MiniI18n.load_default_locales(:es)
      
      expect(MiniI18n.available_locales).to include('es')
      expect(MiniI18n.translations['es']).to have_key('date')
      expect(MiniI18n.translations['es']['date']).to have_key('day_names')
      expect(MiniI18n.translations['es']['date']['day_names']).to include('domingo', 'lunes')
    end

    it 'loads French locale defaults' do
      MiniI18n.load_default_locales(:fr)
      
      expect(MiniI18n.available_locales).to include('fr')
      expect(MiniI18n.translations['fr']).to have_key('date')
      expect(MiniI18n.translations['fr']['date']['day_names']).to include('dimanche', 'lundi')
    end

    it 'loads German locale defaults' do
      MiniI18n.load_default_locales(:de)
      
      expect(MiniI18n.available_locales).to include('de')
      expect(MiniI18n.translations['de']).to have_key('date')
      expect(MiniI18n.translations['de']['date']['day_names']).to include('Sonntag', 'Montag')
    end

    it 'loads Portuguese locale defaults' do
      MiniI18n.load_default_locales(:pt)
      
      expect(MiniI18n.available_locales).to include('pt')
      expect(MiniI18n.translations['pt']).to have_key('date')
      expect(MiniI18n.translations['pt']['date']['day_names']).to include('domingo', 'segunda-feira')
    end

    it 'loads Italian locale defaults' do
      MiniI18n.load_default_locales(:it)
      
      expect(MiniI18n.available_locales).to include('it')
      expect(MiniI18n.translations['it']).to have_key('date')
      expect(MiniI18n.translations['it']['date']['day_names']).to include('domenica', 'lunedì')
    end

    it 'loads Dutch locale defaults' do
      MiniI18n.load_default_locales(:nl)
      
      expect(MiniI18n.available_locales).to include('nl')
      expect(MiniI18n.translations['nl']).to have_key('date')
      expect(MiniI18n.translations['nl']['date']['day_names']).to include('zondag', 'maandag')
    end

    it 'loads multiple locales at once' do
      MiniI18n.load_default_locales(:es, :fr)
      
      expect(MiniI18n.available_locales).to include('es', 'fr')
      expect(MiniI18n.translations['es']['date']['day_names']).to include('domingo')
      expect(MiniI18n.translations['fr']['date']['day_names']).to include('dimanche')
    end

    it 'handles non-existent locales gracefully' do
      expect { MiniI18n.load_default_locales(:nonexistent) }.not_to raise_error
      expect(MiniI18n.available_locales).not_to include('nonexistent')
    end

    it 'can be used for localization' do
      MiniI18n.load_default_locales(:es)
      
      date = Date.new(2023, 12, 25)
      localized_date = MiniI18n.l(date, locale: :es)
      
      expect(localized_date).to eq('25/12/2023')
    end

    it 'can be used for number formatting' do
      MiniI18n.load_default_locales(:es)
      
      number = 1234.56
      localized_number = MiniI18n.l(number, locale: :es)
      
      expect(localized_number).to eq('1.234,56')
    end

    it 'can be used for currency formatting' do
      MiniI18n.load_default_locales(:es)
      
      number = 1234.56
      localized_currency = MiniI18n.l(number, as: :currency, locale: :es)
      
      expect(localized_currency).to eq('1.234,56 €')
    end
  end
end