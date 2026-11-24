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
    products = Noaa::ProductCatalog.new
    render json: { stations: products.enrich(catalog.stations), status: catalog.status,
                   products_warning: products.warning }
  end

  def report
    station = Noaa::Catalog.new.find(params.expect(:id))
    render json: Noaa::StationReport.new(station, hours: params.fetch(:hours, 48),
                                                  units: params.fetch(:units, 'english'),
                                                  future_hours: params.fetch(:future_hours, 0)).call
  end

  def context
    station = Noaa::Catalog.new.find(params.expect(:id))
    render json: Noaa::StationContext.new(station, units: params.fetch(:units, 'english')).call
  end

  def history
    station = Noaa::Catalog.new.find(params.expect(:id))
    render json: Noaa::HistoryReport.new(station, begin_date: params[:begin_date],
                                                  end_date: params[:end_date],
                                                  resolution: params.fetch(:resolution, 'auto'),
                                                  units: params.fetch(:units, 'english')).call
  end

  def nearby
    station = Noaa::Catalog.new.find(params.expect(:id))
    render json: Noaa::NearbyBuoys.new(station, units: params.fetch(:units, 'english'),
                                                hours: params.fetch(:hours, 48)).call
  end

  private

  def no_data(error)
    render json: { error: error.message }, status: :unprocessable_content
  end

  def unavailable(error)
    render json: { error: error.message }, status: :service_unavailable
  end
end
