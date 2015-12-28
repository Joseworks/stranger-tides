namespace :stations_id_list do
  require 'open-uri'

  desc "Station List"
    task :process_station_list => :environment do
      @all_reporting_stations = []
      @all_reporting_stations = TideStation.parse_stations_id
      new_station = Station.find_or_create_by(station_name: "All stations")
      new_station.tide_info = @all_reporting_stations
      new_station.station_name = "All stations"
      new_station.save
    end

  class TideStation
    def self.parse_stations_id
      all_lines = []
      station_id_list = []
      station_list = File.join(Rails.root, 'data', 'station_list.txt')
      file = File.open(station_list, 'r') do |f|
        f.each do |line|
          all_lines << line
        end
      end
      all_lines.each do |line|
       station_id_list << line.split(' ').first.to_i
      end
      p "Done!"
      station_id_list
    end
  end
end
