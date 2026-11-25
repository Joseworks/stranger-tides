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
    render json: StationNetworks.new(params.fetch(:network, 'noaa')).call
  end

  def report
    station = find_station
    provider = uk_station? ? EnvironmentAgency : Noaa
    options = { hours: params.fetch(:hours, 48), units: params.fetch(:units, 'english'),
                future_hours: params.fetch(:future_hours, 0) }
    render json: provider::StationReport.new(station, **options).call
  end

  def context
    station = noaa_station
    render json: Noaa::StationContext.new(station, units: params.fetch(:units, 'english')).call
  end

  def history
    station = find_station
    provider = uk_station? ? EnvironmentAgency : Noaa
    options = { begin_date: params[:begin_date], end_date: params[:end_date],
                resolution: params.fetch(:resolution, 'auto'),
                units: params.fetch(:units, 'english') }
    render json: provider::HistoryReport.new(station, **options).call
  end

  def nearby
    station = noaa_station
    render json: Noaa::NearbyBuoys.new(station, units: params.fetch(:units, 'english'),
                                                hours: params.fetch(:hours, 48)).call
  end

  def photo
    station = noaa_station
    render json: Noaa::StationPhotos.new(station).call
  end

  private

  def uk_station? = params[:id].to_s.start_with?('ea-')

  def find_station
    (uk_station? ? EnvironmentAgency::Catalog : Noaa::Catalog).new.find(params.expect(:id))
  end

  def noaa_station
    raise Noaa::NoData, 'This product is not supplied by the UK tide-gauge API.' if uk_station?

    find_station
  end

  def no_data(error)
    render json: { error: error.message }, status: :unprocessable_content
  end

  def unavailable(error)
    render json: { error: error.message }, status: :service_unavailable
  end
end
