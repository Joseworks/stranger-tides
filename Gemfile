# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.7'
gem 'rails', '~> 8.0.2'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'bigdecimal'
gem 'faraday'
gem 'gon'
gem 'jquery-rails'
gem 'js_assets'
gem 'lazy_high_charts'
gem 'pg'
gem 'puma'
gem 'sassc-rails'
gem 'sidekiq', '< 9.0'
gem 'sprockets', '~> 4.0'
gem 'turbolinks'

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

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# # Use Sass to process CSS
# gem 'sassc-rails'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'pry'
  gem 'pry-byebug'
  gem 'rails-controller-testing'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'simplecov', require: false
end

# Logger fix for Rails 7 https://github.com/facebook/react-native/commit/198adb47af3676c85b35adb308c110c1d87120c8
gem 'concurrent-ruby', '< 1.3.4'

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'bundle-audit'
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # gem 'shoulda-matchers'
end
