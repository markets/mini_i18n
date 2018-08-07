require "mini_i18n"

RSpec.configure do |config|
  config.order = :rand
  config.disable_monkey_patching!

  config.before(:suite) do
    MiniI18n.load_translations File.expand_path(__dir__ + '/fixtures/locales/*')
  end
end
