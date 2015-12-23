include ActiveModel::Model
module GraphProcessorService
  class GraphProcessor
    def self.graph_constructor(station_id)
      current_station = StationDataRangeConstructor.new(station_id)
      constructed_station_params = current_station.range_constructor
      current_product = constructed_station_params[:product]
      @constructed_station = StationConstructor.new(constructed_station_params)
      url = @constructed_station.url_constructor
      @metadata = TideParsingService::TideProcessor.metadata_retrieval(station_id, current_product, url)
      tide_info = TideParsingService::TideProcessor.tide_level_retrieval(station_id, current_product, url)
      time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(station_id, current_product, url)
      tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(station_id, current_product, url)
      GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_info, time_stamp_info)
    end
  end
end