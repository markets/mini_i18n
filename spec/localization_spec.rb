RSpec.describe MiniI18n::Localization do
  let(:time) { Time.new(2018, 8, 7, 22, 30) }

  describe 'date' do
    it 'accepts different formats' do
      date = time.to_date
      expect(MiniI18n.l(date)).to eq 'Tuesday 07, August, 2018'
      expect(MiniI18n.l(date, format: :short)).to eq '07 Aug 18'
    end
  end

  describe 'time' do
    it 'accepts different formats' do
      expect(MiniI18n.l(time)).to eq 'Tue 07, August, 2018 - 22:30'
      expect(MiniI18n.l(time, format: :short)).to eq '07 Aug 18 - 22:30'
    end
  end

  describe 'string' do
    it 'accepts and defaults to time' do
      time_string = time.to_s
      expect(MiniI18n.l(time_string)).to eq 'Tue 07, August, 2018 - 22:30'
      expect(MiniI18n.l(time_string, type: :time)).to eq 'Tue 07, August, 2018 - 22:30'
    end

    it 'to date' do
      date_string = time.to_date.to_s
      expect(MiniI18n.l(date_string, type: :date, format: :short)).to eq '07 Aug 18'
    end

    it 'to number' do
      expect(MiniI18n.l("1000000", type: :number)).to eq '1,000,000.0'
      expect(MiniI18n.l("1000000", as: :currency)).to eq '1,000,000.0 $'
    end
  end

  describe 'number' do
    it 'uses defined format' do
      expect(MiniI18n.l(9000)).to eq '9,000'
      expect(MiniI18n.l(9000.50)).to eq '9,000.5'
    end

    it 'as' do
      expect(MiniI18n.l(9000, as: :currency)).to eq '9,000 $'
      expect(MiniI18n.l(9000, as: :currency, locale: :es)).to eq '9.000 €'
      expect(MiniI18n.l(125.5, as: :distance)).to eq 'Distance -> 125.5 miles'
    end
  end

  describe 'multiple objects' do
    let(:date) { Date.new(2018, 8, 7) }
    let(:number) { 1234.56 }

    it 'localizes multiple objects with same options' do
      result = MiniI18n.l([date, number])
      expect(result).to eq ['Tuesday 07, August, 2018', '1,234.56']
    end

    it 'localizes multiple objects with specific locale' do
      result = MiniI18n.l([number, 9000], locale: :es)
      expect(result).to eq ['1.234,56', '9.000']
    end

    it 'localizes multiple objects with different formats' do
      result = MiniI18n.l([date, time], format: :short)
      expect(result).to eq ['07 Aug 18', '07 Aug 18 - 22:30']
    end

    it 'localizes multiple objects with as option' do
      result = MiniI18n.l([1000, 2000], as: :currency)
      expect(result).to eq ['1,000 $', '2,000 $']
    end
  end

  describe 'multiple locales' do
    let(:number) { 1234.56 }

    it 'localizes same object for multiple locales' do
      result = MiniI18n.l(number, locale: [:en, :es])
      expect(result).to eq ['1,234.56', '1.234,56']
    end

    it 'localizes date for multiple locales' do
      date = Date.new(2018, 8, 7)
      result = MiniI18n.l(date, locale: [:en, :es])
      expect(result).to eq ['Tuesday 07, August, 2018', '7/8/2018']
    end

    it 'localizes time for multiple locales' do
      result = MiniI18n.l(time, locale: [:en, :es])
      expect(result).to eq ['Tue 07, August, 2018 - 22:30', 'mar 7 de agosto de 2018 - 22:30']
    end

    it 'localizes number with currency for multiple locales' do
      result = MiniI18n.l(1000, as: :currency, locale: [:en, :es])
      expect(result).to eq ['1,000 $', '1.000 €']
    end

    it 'localizes with format for multiple locales' do
      date = Date.new(2018, 8, 7)
      result = MiniI18n.l(date, format: :short, locale: [:en, :es])
      expect(result).to eq ['07 Aug 18', '7 ago 18']
    end
  end


end
