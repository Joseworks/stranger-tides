# frozen_string_literal: true

namespace :station_list do
  desc 'Process metadata'
  task retrieve_all_stations_metadata: :environment do
    puts 'Processing all stations'
    # The intention is not to invoke directly stations_id_list, but invoke it from this task, ensuring that there will be an existing record once we finish.
    Rake::Task['stations_id_list:process_station_list'].reenable
    Rake::Task['stations_id_list:process_station_list'].invoke

    @all_reporting_stations = Station.last.tide_info
    @all_charts = []
    @all_station_metadata = []

    # p "@all_reporting_stations.inspect --- #{@all_reporting_stations.inspect}"

    @all_reporting_stations.each do |station_id|
      puts
      puts "Now processing #{station_id} \n"
      puts

      datum ||= TideParsingService::TideProcessor.datum_retrieval(station_id)

      if datum.size == 1
        datum = datum.first

        if datum == 'GL_LWD'
          datum = 'IGLD'
        elsif datum == 'MLLW'
          datum
        end

      elsif datum.include?('GL_LWD')
        datum = 'IGLD'
      elsif datum.include?('MLLW')
        datum = 'MLLW'
      elsif datum.include?('MSL')
        datum = 'MSL'
      end

      datum = 'IGLD' if datum.nil? || datum.empty?

      current_station ||= StationDataRangeConstructor.new(station_id, datum)
      constructed_station_params = current_station.range_constructor
      current_product = constructed_station_params[:product] # "water_level"
      @constructed_station = StationConstructor.new(constructed_station_params)

      @path_build = @constructed_station.url_constructor

      @metadata = TideParsingService::TideProcessor.metadata_retrieval(station_id, current_product,
                                                                       @path_build)

      @all_station_metadata << @metadata unless @metadata.nil?
    end

    new_station = Station.find_or_create_by(station_name: 'All stations')
    new_station.metadata = @all_station_metadata
    new_station.save
    p 'Done!'
  end
end
