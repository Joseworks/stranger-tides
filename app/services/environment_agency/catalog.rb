# frozen_string_literal: true

module EnvironmentAgency
  class Catalog
    UNITS = %w[mAOD m].freeze
    ID = /\Aea-([A-Za-z0-9]{1,40})\z/
    ATTRIBUTION = 'This uses Environment Agency tide gauge data from the real-time data API (Beta).'

    def initialize(client: Client.new)
      @client = client
    end

    def stations
      return @stations if defined?(@stations)

      payload = @client.get('/id/stations', { type: 'TideGauge', _limit: 1000 },
                            expires_in: 6.hours)
      rows = payload.fetch('items').filter_map { |row| normalize(row) }
      rows.sort_by! { |row| row['datum'] == 'ODN' ? 0 : 1 }
      @stations = rows.uniq { |row| row['station_name'] }.sort_by { |row| row['station_name'] }
    end

    def find(id)
      raise Noaa::NoData, 'Choose a valid Environment Agency station.' unless ID.match?(id.to_s)

      stations.find { |station| station['station_id'] == id } ||
        raise(Noaa::NoData, 'This UK station is not in the current catalog.')
    end

    private

    def normalize(row)
      return unless row.is_a?(Hash) && ID.match?("ea-#{row['stationReference']}")
      return if row['status'].present? && !row['status'].to_s.end_with?('/statusActive')

      measure = tidal_measure(row)
      lat, lon = coordinates(row)
      return unless measure && lat && lon && row['label'].is_a?(String) && row['label'].present?

      build_station(row, measure, lat, lon)
    end

    def tidal_measure(row)
      Array(row['measures']).find do |item|
        item.is_a?(Hash) && item['parameter'] == 'level' && item['qualifier'] == 'Tidal Level' &&
          UNITS.include?(item['unitName']) && item['period'] == 900
      end
    end

    def coordinates(row)
      lat = Float(row['lat'], exception: false)
      lon = Float(row['long'], exception: false)
      [lat&.between?(-90, 90) ? lat : nil, lon&.between?(-180, 180) ? lon : nil]
    end

    def build_station(row, measure, lat, lon)
      source_url = "#{Client::ORIGIN}#{Client::ROOT}/id/stations/#{row['stationReference']}"
      { 'station_id' => "ea-#{row['stationReference']}", 'source_id' => row['stationReference'],
        'station_name' => row['label'].truncate(200), 'latitude' => lat, 'longitude' => lon,
        'state' => 'UK', 'provider' => 'environment_agency', 'capabilities' => ['waterlevels'],
        'additional_products' => [],
        'datum' => measure['unitName'] == 'mAOD' ? 'ODN' : 'Local datum',
        'source_unit' => measure['unitName'], 'station_timezone' => 'Europe/London',
        'source_status' => row['status'].present? ? 'active' : 'not supplied',
        'source_url' => source_url }
    end
  end
end
