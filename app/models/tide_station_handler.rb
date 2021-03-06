  class TideStationHandler
    def initialize
      @all_lines = []
      @station_id_list = []
      if Rails.env.production?
        @station_list =
          File.join(Rails.root, 'data', 'station_list.txt')
      else
        @station_list =
          File.join(Rails.root, 'spec', '/fixtures/station_list_fixture.txt')
      end
    end

    def parse_stations_id
      File.open(station_list, 'r') do |f|
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

    attr_accessor :all_lines, :station_id_list, :station_list
  end
