require "bundler/setup"
require "mini_i18n"

RSpec.configure do |config|
  config.order = :rand
  config.disable_monkey_patching!
end
