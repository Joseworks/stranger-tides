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
    record = Station.find_by!(id: ENV.fetch('SNAPSHOT_ID'), station_name: Noaa::Catalog::SNAPSHOT_NAME)
    Station.create!(station_name: record.station_name, metadata: record.metadata,
                    tide_info: record.tide_info)
    puts "Restored catalog snapshot #{record.id}."
  end
end
