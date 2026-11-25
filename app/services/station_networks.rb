# frozen_string_literal: true

class StationNetworks
  def initialize(network)
    @network = network
    raise Noaa::NoData, 'Choose a supported station network.' unless %w[noaa uk
                                                                        all].include?(network)
  end

  def call
    return uk if @network == 'uk'
    return noaa if @network == 'noaa'

    warnings = []
    results = [-> { noaa }, -> { uk }].filter_map do |retrieve|
      retrieve.call
    rescue Noaa::Unavailable, Noaa::NoData => e
      warnings << e.message
      nil
    end
    raise Noaa::Unavailable, warnings.join(' ') if results.empty?

    { stations: results.flat_map { |result| result[:stations] }, status: results.first[:status],
      network_warnings: warnings, products_warning: results.any? { |r| r[:products_warning] } }
  end

  private

  def noaa
    catalog = Noaa::Catalog.new
    products = Noaa::ProductCatalog.new
    { stations: products.enrich(catalog.stations), status: catalog.status,
      products_warning: products.warning }
  end

  def uk
    { stations: EnvironmentAgency::Catalog.new.stations,
      status: { refreshed_at: Time.current.iso8601, stale: false } }
  end
end
