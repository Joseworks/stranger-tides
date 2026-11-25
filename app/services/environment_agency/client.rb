# frozen_string_literal: true

module EnvironmentAgency
  class Client
    ORIGIN = 'https://environment.data.gov.uk'
    ROOT = '/flood-monitoring'

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    def get(path, params = {}, expires_in: 15.minutes)
      @cache.fetch(['ea-v1', path, params.sort], expires_in:) do
        connection = Faraday.new(url: ORIGIN) do |http|
          http.options.open_timeout = 2
          http.options.timeout = 10
        end
        response = connection.get(ROOT + path, params)
        raise Noaa::Unavailable unless response.success? && response.body.bytesize <= 4.megabytes

        payload = JSON.parse(response.body)
        raise Noaa::Unavailable unless payload.is_a?(Hash) && payload['items'].is_a?(Array)

        payload
      end
    rescue Faraday::Error, JSON::ParserError, Noaa::Unavailable
      raise Noaa::Unavailable, 'Environment Agency data are temporarily unavailable. Please retry.'
    end
  end
end
