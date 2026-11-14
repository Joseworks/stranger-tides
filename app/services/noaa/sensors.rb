# frozen_string_literal: true

module Noaa
  class Sensors
    PRODUCTS = {
      'Wind' => 'wind', 'Water Temperature' => 'water_temperature',
      'Air Temperature' => 'air_temperature', 'Barometric Pressure' => 'air_pressure',
      'Relative Humidity' => 'humidity'
    }.freeze

    def initialize(id, client:)
      @id = id
      @client = client
    end

    def call
      payload = @client.get("/mdapi/prod/webapi/stations/#{@id}/sensors.json", {},
                            expires_in: 6.hours)
      sensors = Array(payload['sensors']).filter_map do |sensor|
        next unless sensor.is_a?(Hash) && PRODUCTS.key?(sensor['name'])

        { product: PRODUCTS.fetch(sensor['name']), name: sensor['name'],
          enabled: sensor['status'] == 1, message: sensor['message'].to_s.split('&', 2).last }
      end
      sensors.uniq { |sensor| sensor[:product] }
    end
  end
end
