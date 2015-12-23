class StationsController < ApplicationController
  before_action :set_station, only: [:show_stations, :show_graph]

  def show_stations
    gon.all_station_metadata = @all_station_metadata
  end

  def show_graph
    gon.all_station_metadata = @all_station_metadata
    if request.xhr?
      respond_to do |format|
        @chart = GraphProcessorService::GraphProcessor.graph_constructor(params[:content])
         format.js
      end
    end
  end


  private
    def set_station
      @all_station_metadata = Station.last.metadata
    end

    def station_params
      params.require(:station).permit(:station_id, :station_name, :latitude, :longitude, :tide_info, :metadata, :range_constructor)
    end
  end
