source 'https://rubygems.org'
ruby '2.7.2'

gem 'rails', '5.2.4.4'
gem 'pg', '~> 0.21'
gem 'passages'
gem 'bigdecimal', '1.3.5'
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
gem 'jquery-rails'
gem 'turbolinks'
gem 'lazy_high_charts'
gem 'gon'
gem 'js_assets'
gem 'sidekiq'
gem 'redis'
gem 'unicorn'

group :development, :test do
  gem 'pry'
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.0'
  gem "factory_bot_rails"
  gem 'simplecov', :require => false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec'
end

group  :test do
  gem 'shoulda-matchers', '~> 3.0'
end

group :development do
  gem 'bullet'
end

group :production do
  gem  'rails_12factor'
end
