# frozen_string_literal: true

namespace :spec do
  desc 'Create rspec coverage'
  task coverage: :environment do
    ENV['COVERAGE'] = 'true'
    Rake::Task['spec'].execute
  end
end
