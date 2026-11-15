# frozen_string_literal: true

module Noaa
  class WaterLevelDatum
    def initialize(station, client:)
      @station = station
      @client = client
    end

    def call
      capabilities = @station.fetch('capabilities', [])
      return nil unless capabilities.intersect?(%w[waterlevels tidepredictions])
      return 'MLLW' unless capabilities.include?('waterlevels')

      path = "/mdapi/prod/webapi/stations/#{@station.fetch('station_id')}/datums.json"
      payload = @client.get(path, {}, expires_in: 1.day)
      names = Array(payload['datums']).filter_map { |row| row['name'] if row.is_a?(Hash) }
      return 'IGLD' if names.intersect?(%w[IGLD GL_LWD])

      %w[MLLW MSL STND].find { |name| names.include?(name) } ||
        raise(NoData, 'NOAA has not published a supported height reference for this station.')
    end
  end
end
