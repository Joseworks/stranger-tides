# frozen_string_literal: true

namespace :deploy do
  desc 'Production deployment requires the reviewed staging promotion procedure'
  task production: :environment do
    abort 'Automatic production deployment is disabled. ' \
          'Follow docs/upgrading.md after staging and security review.'
  end
end
