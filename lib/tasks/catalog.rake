# frozen_string_literal: true

namespace :stations do
  desc 'Validate current NOAA catalogs and print changes; APPLY=1 publishes a new snapshot'
  task refresh: :environment do
    result = Noaa::Catalog.new.refresh(apply: ENV['APPLY'] == '1',
                                       allow_removals: ENV['ALLOW_REMOVALS'] == '1')
    puts JSON.pretty_generate(result)
  end

  desc 'Restore a previous catalog snapshot without deleting history; SNAPSHOT_ID is required'
  task rollback: :environment do
    snapshot_id = ENV.fetch('SNAPSHOT_ID')
    restored = Noaa::CatalogPublisher.restore(snapshot_id:)
    puts "Restored catalog snapshot #{snapshot_id} as publication #{restored.id}."
  end
end
