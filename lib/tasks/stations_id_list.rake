# frozen_string_literal: true

namespace :stations_id_list do
  desc 'Station List'
  task process_station_list: :environment do
    unless Rails.env.test?
      abort 'Manual imports are retired. Use stations:refresh to validate the current NOAA catalog.'
    end

    @all_reporting_stations = []
    @all_reporting_stations = TideStationHandler.new.parse_stations_id
    new_station = Station.find_or_create_by(station_name: 'All stations')
    new_station.tide_info = @all_reporting_stations
    new_station.station_name = 'All stations'
    new_station.save
  end
end
