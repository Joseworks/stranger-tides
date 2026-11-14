# frozen_string_literal: true

# Only this origin may request location. The browser still asks for user consent.
Rails.application.config.action_dispatch.default_headers['Permissions-Policy'] =
  'geolocation=(self)'

# Rails emits the older Feature-Policy syntax for browsers that support it.
Rails.application.config.permissions_policy do |policy|
  policy.geolocation :self
end
