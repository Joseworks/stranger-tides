# frozen_string_literal: true

class StationsController < ApplicationController
  rescue_from Noaa::NoData, with: :no_data
  rescue_from Noaa::Unavailable, with: :unavailable

  def show_stations; end

  # Old open browser tabs receive a clear refresh instruction instead of executing legacy JS.
  def show_graph
    render json: { error: 'Please reload the page to use the updated station explorer.' },
           status: :gone
  end

  def catalog
    catalog = Noaa::Catalog.new
    render json: { stations: catalog.stations, status: catalog.status }
  end

  def report
    station = Noaa::Catalog.new.find(params.expect(:id))
    render json: Noaa::StationReport.new(station, hours: params.fetch(:hours, 48),
                                                  units: params.fetch(:units, 'english')).call
  end

  private

  def no_data(error)
    render json: { error: error.message }, status: :unprocessable_content
  end

  def unavailable(error)
    render json: { error: error.message }, status: :service_unavailable
  end
end
