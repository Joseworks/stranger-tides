source 'https://rubygems.org'
ruby '2.4.2'

gem 'rails', '4.2.10'
gem 'pg'
gem 'passages'

gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
gem 'jquery-rails'
gem 'turbolinks'

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'lazy_high_charts'
gem 'gon'
gem 'js_assets'
gem 'sidekiq'
gem 'redis'
gem 'unicorn'



group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'rails-pry'
  gem 'pry-rescue'
  gem 'rspec-rails', '~> 3.0'
  gem "factory_bot_rails"
  gem 'simplecov', :require => false
  gem 'rubocop', require: false
  gem 'rubocop-rspec'
end

group  :test do
  gem 'shoulda-matchers', '~> 3.0'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'
  gem 'bullet'
end

group :production do
  gem  'rails_12factor'
end

