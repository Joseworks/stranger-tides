class StationsController < ApplicationController
  before_action :set_station, only: [:show, :edit, :update, :destroy]

  def show_station
    # Temporary override to ensure showing one station. Needs to receive from js the id of the station marker.
    @all_station_metadata = Station.last.metadata
    # tide_info = TideParsingService::TideProcessor.tide_level_retrieval(station_id, current_product, url)
    # time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(station_id, current_product, url)
    # tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(station_id, current_product, url)
    @chart =GraphProcessorService::GraphProcessor.graph_constructor(@all_station_metadata)


    #   @chart1 = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_s_info, time_stamp_info)
  end



  def show_stations
    @all_station_metadata = Station.last.metadata
    gon.all_station_metadata = @all_station_metadata
  end



  def show_graph
    @all_station_metadata = Station.last.metadata
    gon.all_station_metadata = @all_station_metadata

    if request.xhr?
      respond_to do |format|
        @chart = GraphProcessorService::GraphProcessor.graph_constructor(params[:content])
         format.js
      end
    end
  end




  private
    # Use callbacks to share common setup or constraints between actions.
    def set_station
      @station = Station.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def station_params
      params.require(:station).permit(:station_id, :station_name, :latitude, :longitude, :tide_info, :metadata, :range_constructor)
    end
  end
