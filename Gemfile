# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.7'
gem 'rails', '~> 8.1.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'bigdecimal'
gem 'drb'
gem 'faraday'
gem 'gon'
gem 'jquery-rails'
gem 'lazy_high_charts'
gem 'mutex_m' # Mutex_m is a simple mutex class for Ruby, resolve warning in Rails 7
gem 'pg'
gem 'puma'
gem 'sassc-rails'
gem 'redis', '~> 5.0' # Action Cable; the application has no Sidekiq workers
gem 'sprockets', '~> 4.0'
gem 'turbolinks'

# JavaScript handling
gem 'importmap-rails'
gem 'sprockets-rails', '~> 3.5'

# Use Redis adapter to run Action Cable in production
# gem 'redis'

# Use Active Model has_secure_password
# [https://guides.rubyonrails.org/active_model_basics.html
# #securepassword]
# gem "bcrypt", "~> 3.1.7"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
# gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
# gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
# gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
# gem 'redis'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password
# [https://guides.rubyonrails.org/active_model_basics.html
# #securepassword]
# gem "bcrypt", "~> 3.1.7"

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# # Use Sass to process CSS
# gem 'sassc-rails'

# Use Active Storage variants
# [https://guides.rubyonrails.org/active_storage_overview.html
# #transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'pry'
  gem 'pry-byebug'
  gem 'rails-controller-testing'
  gem 'rspec-rails'
  # Code quality
  gem 'brakeman', require: false
  gem 'bullet', require: false
  gem 'bundler-audit', require: false
  gem 'debride', require: false
  # gem 'flay', require: false
  # gem 'flog', require: false
  # gem 'reek', require: false
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'simplecov', require: false
end

gem 'logger'

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  gem 'webmock'
end
