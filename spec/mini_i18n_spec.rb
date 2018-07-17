RSpec.describe MiniI18n do
  before(:all) do
    MiniI18n.load_translations File.expand_path __dir__ + '/fixtures/locales/*'
  end

  before(:each) do
    MiniI18n.locale = :en
    MiniI18n.fallbacks = false
  end

  describe 'load_translations' do
    it "allows to load multiple locales and translations from different files" do
      expect(MiniI18n.available_locales).to eq ["en", "es", "fr"]
      expect(MiniI18n.translations.size). to eq 3
      expect(MiniI18n.translations["en"]).to include 'bye'
    end
  end

  describe 'translate' do
    it "simple key" do
      expect(MiniI18n.t(:hello)).to eq 'hello'
    end

    it "nested key" do
      expect(MiniI18n.t('second_level')).to be_a Hash
      expect(MiniI18n.t('second_level.hello')).to eq 'hello 2'
    end

    it "locale" do
      expect(MiniI18n.t('hello', locale: :fr)).to eq 'bonjour'
      expect(MiniI18n.t('hello', locale: :es)).to eq 'hola'
    end

    it "scope" do
      expect(MiniI18n.t('hello', scope: :second_level)).to eq 'hello 2'
    end

    it "returns nil if key does not exist" do
      expect(MiniI18n.t('foo')).to eq nil
    end

    it "returns default if key does not exist" do
      expect(MiniI18n.t('foo', default: 'bar')).to eq 'bar'
    end

    it "with interpolation" do
      expect(MiniI18n.t('hello_interpolation')).to eq 'hello %{name}'
      expect(MiniI18n.t('hello_interpolation', name: 'world')).to eq 'hello world'
    end

    it "fallbacks" do
      expect(MiniI18n.t('fallback', locale: :es)).to eq ''

      MiniI18n.fallbacks = true
      expect(MiniI18n.t('fallback', locale: :es)).to eq 'fallback'
    end
  end

  describe 'locale' do
    it 'allows to change locale globally' do
      MiniI18n.locale = :en
      expect(MiniI18n.t(:hello)).to eq 'hello'

      MiniI18n.locale = :es
      expect(MiniI18n.t(:hello)).to eq 'hola'
    end
  end
end
