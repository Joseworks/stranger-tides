# frozen_string_literal: true

# Makes the API request and process all the information  in order to pass it to the ChartProcessor.


module GraphProcessorService
  class GraphProcessor
    def self.graph_constructor(station_id)
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
      current_product = constructed_station_params[:product]
      @constructed_station = StationConstructor.new(constructed_station_params)
      url = @constructed_station.url_constructor
      @metadata = TideParsingService::TideProcessor.metadata_retrieval(
        station_id, current_product, url
      )
      tide_info = TideParsingService::TideProcessor.tide_level_retrieval(
        station_id, current_product, url
      )
      time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(
        station_id, current_product, url
      )
      # tide_s_info
      TideParsingService::TideProcessor.tide_s_retrieval(station_id,
                                                         current_product, url)
      GraphingService::ChartProcessor.grapher(@metadata.station_name,
                                              tide_info, time_stamp_info)
    end
  end
end
