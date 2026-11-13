# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '2.0'

# The old shared cache can reference SassC processors removed by this upgrade.
Rails.application.config.assets.configure do |environment|
  environment.cache = Sprockets::Cache::FileStore.new(
    Rails.root.join('tmp/cache/assets-v2').to_s,
    Rails.application.config.assets.cache_limit,
    environment.logger
  )
end

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
