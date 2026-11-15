# frozen_string_literal: true

module Noaa
  # Bulk capability discovery is separate from the immutable station inventory.
  class ProductCatalog
    EXTRA = %w[conductivity salinity specific_gravity visibility air_gap].freeze
    attr_reader :warning

    def initialize(client: Client.new)
      @client = client
    end

    def enrich(stations)
      return stations if stations.empty?

      rows = @client.get(Catalog::PATH, { type: 'waterlevelsandmet', expand: 'sensors' },
                         expires_in: 6.hours)
      entries = rows['stations']
      raise Unavailable, 'Product discovery is incomplete.' unless
        entries.is_a?(Array) && rows['count'] == entries.length && entries.all?(Hash)

      one_minute = one_minute_ids
      index = entries.index_by { |row| row['id'] }
      stations.map { |station| enrich_station(station, index[station['station_id']], one_minute) }
    rescue NoData, Unavailable => e
      @warning = e.message
      stations.map { |station| station.merge('products_checked' => false) }
    end

    private

    def enrich_station(station, row, one_minute)
      return station.merge('additional_products' => [], 'products_checked' => false) unless row

      sensors = row['sensors'].is_a?(Hash) ? row['sensors']['sensors'] : []
      products = Sensors.normalize(sensors).select { |s| s[:enabled] }.pluck(:product) & EXTRA
      products << 'one_minute_water_level' if one_minute.include?(station['station_id'])
      products << 'specific_gravity' if products.include?('salinity')
      products << 'ofs_water_level' if row['forecast'] == true
      products << 'flood_outlook' if row['outlook'] == true
      station.merge('additional_products' => products.uniq, 'products_checked' => true,
                    'forecast' => row['forecast'] == true, 'outlook' => row['outlook'] == true)
    end

    def one_minute_ids
      payload = @client.get(Catalog::PATH, { type: '1minute' }, expires_in: 6.hours)
      entries = payload['stations']
      raise Unavailable, 'One-minute product discovery is incomplete.' unless
        entries.is_a?(Array) && payload['count'] == entries.length && entries.all?(Hash)

      entries.pluck('id')
    rescue NoData, Unavailable => e
      @warning = e.message
      []
    end
  end
end
