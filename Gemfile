# frozen_string_literal: true

source 'https://rubygems.org'

ruby file: '.ruby-version'
gem 'rails', '~> 8.1.4'

gem 'bigdecimal'
gem 'drb'
gem 'faraday', '~> 2.15'
gem 'gon', '~> 8.0'
gem 'jquery-rails', '~> 4.6'
gem 'lazy_high_charts', '~> 1.6'
gem 'logger'
gem 'mutex_m'
gem 'pg', '~> 1.7'
gem 'puma', '~> 8.0'
# Action Cable uses Redis; this application has no Sidekiq workers.
gem 'redis', '~> 5.4'

# Keep the existing JavaScript pipeline while upgrading the server runtime.
gem 'importmap-rails', '~> 2.2'
gem 'sprockets', '~> 4.4'
gem 'sprockets-rails', '~> 3.5'
gem 'turbolinks', '~> 5.2'
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'factory_bot_rails'
  gem 'pry'
  gem 'pry-byebug'
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 8.1'

  gem 'brakeman', require: false
  gem 'bullet', require: false
  gem 'bundler-audit', require: false
  gem 'debride', require: false
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'simplecov', require: false
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'webmock'
end
