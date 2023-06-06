# frozen_string_literal: true

class StationsController < ApplicationController
  before_action :set_station, only: %i[show_stations show_graph]

  def show_stations
    gon.all_station_metadata = @all_station_metadata
  end

  def show_graph
    gon.all_station_metadata = @all_station_metadata
    return unless request.xhr?

    respond_to do |format|
      @chart = GraphProcessorService::GraphProcessor.new(params[:content]).call
      format.js
    end
  end

  private

  def set_station
    @station = Station.last
    @all_station_metadata = @station.metadata if @station
  end

  def station_params
    params.require(:content)
  end
end
