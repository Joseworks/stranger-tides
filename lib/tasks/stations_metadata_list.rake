namespace :station_list do
  require 'open-uri'

  desc "Process metadata"
    task :retrieve_all_stations_metadata => :environment do
      puts "Processing all stations"
      # The intention is not to invoke directly stations_id_list, but invoke it from this taks, ensurin that there will be an existing record once we finish.
      Rake::Task["stations_id_list:process_station_list"].reenable
      Rake::Task["stations_id_list:process_station_list"].invoke

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
      new_station.metadata = @all_station_metadata
      new_station.save
      p 'Done!'
    end
end