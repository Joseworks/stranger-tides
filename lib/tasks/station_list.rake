namespace :station_list do
  require 'open-uri'

  desc "Delete Station List"
    task :delete_station_list => :environment do
      Station.delete_all
      p "All stations have been erased"
    end


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




  desc "Run Process"
    task :process_all_stations => :environment do
      puts "Processing all stations"

      @all_reporting_stations = Station.last.tide_info
      @all_charts = []
      @all_station_metadata = []

      @all_reporting_stations.each do |station_id|
        current_station = StationDataRangeConstructor.new(station_id)
        constructed_station_params = current_station.range_constructor
        current_product = constructed_station_params[:product]
        @constructed_station = StationConstructor.new(constructed_station_params)
        @path_build = @constructed_station.url_constructor
        url = @path_build
        @metadata = TideParsingService::TideProcessor.metadata_retrieval(station_id, current_product, url)

        unless @metadata.nil?
          @all_station_metadata << @metadata
        end
      end

    new_station = Station.find_or_create_by(station_name: "All stations")
    new_station = Station.last
    new_station.metadata = @all_station_metadata
    new_station.save
    p 'Done!'
    end

end
