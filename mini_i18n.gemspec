require "./lib/mini_i18n/version"

Gem::Specification.new do |spec|
  spec.name          = "mini_i18n"
  spec.version       = MiniI18n::VERSION
  spec.summary       = "Minimalistic I18n library for Ruby"
  spec.description   = "#{spec.summary}. It supports localization, pluralization, interpolations, fallbacks, nested keys and more."
  spec.authors       = ["markets"]
  spec.email         = ["srmarc.ai@gmail.com"]
  spec.homepage      = "https://github.com/markets/mini_i18n"
  spec.license       = "MIT"
  spec.files         = Dir.glob("lib/**/*")
  spec.test_files    = Dir.glob("spec/**/*")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "byebug"
end
