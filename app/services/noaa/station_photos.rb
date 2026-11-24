# frozen_string_literal: true

module Noaa
  class StationPhotos
    PHOTO_ROOT = 'https://cdn.tidesandcurrents.noaa.gov/assets/stationphotos'
    INDEX_URL = "#{PHOTO_ROOT}/photo.json".freeze

    def initialize(station, cache: Rails.cache)
      @station = station
      @cache = cache
    end

    def call
      id = @station.fetch('station_id')
      suffixes = catalog[id]
      available = id.match?(/\A[A-Za-z0-9]+\z/) && suffixes.is_a?(String) &&
                  suffixes.match?(/\A[A-Za-z0-9]{1,20}\z/)
      { station_id: id, image_url: available ? "#{PHOTO_ROOT}/#{id}#{suffixes[0]}.jpg" : nil,
        photo_count: available ? suffixes.length : 0,
        gallery_url: "https://tidesandcurrents.noaa.gov/stationphotos.html?id=#{ERB::Util.url_encode(id)}",
        source: 'NOAA CO-OPS' }
    end

    private

    def catalog
      @cache.fetch('noaa-station-photos-v1', expires_in: 1.day) { retrieve }
    end

    def retrieve
      connection = Faraday.new do |http|
        http.options.open_timeout = 2
        http.options.timeout = 5
      end
      response = connection.get(INDEX_URL)
      raise Unavailable, 'NOAA station photos are temporarily unavailable.' unless response.success?

      payload = JSON.parse(response.body)
      unless payload.is_a?(Hash)
        raise Unavailable, 'NOAA station photos are temporarily unavailable.'
      end

      payload
    rescue Faraday::Error, JSON::ParserError
      raise Unavailable, 'NOAA station photos are temporarily unavailable.'
    end
  end
end
