# frozen_string_literal: true

# Makes the API request and process all the information  in order to pass it to the ChartProcessor.

module GraphProcessorService
  class GraphProcessor
    def initialize(station_id)
      @station_id = station_id
    end

    def call
      graph_constructor
    end

    private

    def graph_constructor
      datum_processor
      # tide_s_info
      TideParsingService::TideProcessor.tide_s_retrieval(station_id, current_product, url)
      GraphingService::ChartProcessor.grapher(metadata.station_name, tide_info, time_stamp_info)
    end

    def current_station
      @current_station ||= StationDataRangeConstructor.new(station_id, @datum)
    end

    def constructed_station_params
      current_station.range_constructor
    end

    def current_product
      constructed_station_params[:product]
    end

    def constructed_station
      StationConstructor.new(constructed_station_params)
    end

    def url
      constructed_station.url_constructor
    end

    def metadata
      TideParsingService::TideProcessor.metadata_retrieval(station_id, current_product, url)
    end

    def tide_info
      TideParsingService::TideProcessor.tide_level_retrieval(station_id, current_product, url)
    end

    def time_stamp_info
      TideParsingService::TideProcessor.time_stamp_retrieval(station_id, current_product, url)
    end

    def datum_processor


      @datum = TideParsingService::TideProcessor.datum_retrieval(station_id)

      if @datum.size == 1
        @datum = @datum.first
        # IGLD Datum reference https://tidesandcurrents.noaa.gov/datum_options.html#:~:text=for%20the%20station.-,Geodetic%20Datums,-The%20National%20Geodetic

        if @datum == 'GL_LWD'
          @datum = 'IGLD'
        elsif @datum == 'MLLW'
          @datum
        end

      elsif @datum.include?('GL_LWD')
        @datum = 'IGLD'
      elsif @datum.include?('MLLW')
        @datum = 'MLLW'
      elsif @datum.include?('MSL')
        @datum = 'MSL'
      end

      @datum = 'IGLD' if @datum.blank?
      @datum
    end
    attr_accessor :station_id, :datum
  end
end
