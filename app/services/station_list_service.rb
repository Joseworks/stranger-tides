# frozen_string_literal: true

module StationListService
  class TideStation
    def self.parse_stations_id
      all_lines = []
      station_id_list = []
      station_list = File.join(Rails.root, 'data', 'station_list.txt')
      File.open(station_list, 'r') do |f|
        f.each do |line|
          all_lines << line
        end
      end
      all_lines.each do |line|
        station_id_list << line.split.first.to_i
      end
      station_id_list
    end
  end
end
