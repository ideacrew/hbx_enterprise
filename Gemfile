source 'https://rubygems.org'

# Distribute your app as a gem
# gemspec

# Server requirements
# gem 'thin' # or mongrel
# gem 'trinidad', :platform => 'jruby'

# Optional JSON codec (faster performance)
# gem 'oj'

# Project requirements
gem 'rake'
gem 'activesupport', '4.1.8'
gem 'activemodel', '4.1.8'
gem 'faraday', '0.11.0'

# Component requirements
gem 'haml', '4.0.6'

# Test requirements
gem 'rspec', :group => 'test'
gem 'rack-test', :require => 'rack/test', :group => 'test'

# Padrino Stable Gem
gem 'padrino', '0.12.4'
gem 'bunny', '1.6.3'
gem 'nokogiri', '1.6.5'
gem 'forkr', '1.0.2'
gem 'net-ssh', '2.9.1'
gem 'net-sftp', '2.1.2'
gem 'json', '~> 1.8.5'
gem 'pry'

# Or Padrino Edge
# gem 'padrino', :github => 'padrino/padrino-framework'

# Or Individual Gems
# %w(core support gen helpers cache mailer admin).each do |g|
#   gem 'padrino-' + g, '0.12.4'
# end

# nfp gem for parsing and integration
gem 'nfp_integration', git:  "https://github.com/dchbx/nfp_integration.git", :tag => '0.0.11'


group :production do
  gem 'unicorn', '4.8.3'
#  gem 'bluepill', '0.0.68'
  gem 'eye', '0.6.4'
end

group :development do
  gem 'capistrano', '3.2.1'
  gem 'capistrano-scm-gitcopy', '0.0.7'
  gem 'capistrano-bundler'
end

group :test do
 gem "rspec_junit_formatter", "0.2.3"
end

gem 'nokogiri-happymapper', '0.5.9', :require => 'happymapper'
