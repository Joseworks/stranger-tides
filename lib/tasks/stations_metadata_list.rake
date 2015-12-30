namespace :station_list do
  require 'open-uri'

  desc "Process metadata"
    task :retrieve_all_stations_metadata => :environment do
      puts "Processing all stations"
        if Station.count == 0
          # p " You need to retrieve the stations id first"
          # p " Please ensure to run 'stations_id_list:process_station_list"
          Rake::Task["stations_id_list:process_station_list"].invoke
        end
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
        p new_station.metadata
    end
end