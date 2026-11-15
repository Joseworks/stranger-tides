# frozen_string_literal: true

module Noaa
  class Sensors
    PRODUCTS = {
      'Wind' => 'wind', 'Water Temperature' => 'water_temperature',
      'Air Temperature' => 'air_temperature', 'Barometric Pressure' => 'air_pressure',
      'Relative Humidity' => 'humidity', 'Conductivity' => 'conductivity',
      'Visibility' => 'visibility', 'AIR GAP' => 'air_gap', 'Air Gap' => 'air_gap'
    }.freeze

    def self.supported?(sensor)
      sensor.is_a?(Hash) && PRODUCTS.key?(sensor['name'])
    end

    def self.normalize(rows)
      sensors = Array(rows).filter_map do |sensor|
        next unless supported?(sensor)

        { product: PRODUCTS.fetch(sensor['name']), name: sensor['name'],
          enabled: sensor['status'] == 1, message: sensor['message'].to_s.split('&', 2).last }
      end
      if sensors.any? { |sensor| sensor[:product] == 'conductivity' && sensor[:enabled] }
        sensors << { product: 'salinity', name: 'Salinity / specific gravity', enabled: true,
                     message: '' }
      end
      sensors.group_by { |sensor| sensor[:product] }.values.map do |group|
        group.find { |sensor| sensor[:enabled] } || group.first
      end
    end

    def initialize(id, client:)
      @id = id
      @client = client
    end

    def call
      payload = @client.get("/mdapi/prod/webapi/stations/#{@id}/sensors.json", {},
                            expires_in: 6.hours)
      self.class.normalize(payload['sensors'])
    end
  end
end
