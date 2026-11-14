# frozen_string_literal: true

module Noaa
  class Client
    ORIGIN = 'https://api.tidesandcurrents.noaa.gov'

    def initialize(cache: Rails.cache, deadline: nil)
      @cache = cache
      @deadline = deadline
      @connection = Faraday.new(url: ORIGIN) do |connection|
        connection.options.open_timeout = 2
        connection.options.timeout = 5
      end
    end

    def get(path, params = {}, expires_in: 1.minute)
      @cache.fetch(['noaa-v1', path, params.sort], expires_in:) { retrieve(path, params) }
    end

    private

    def retrieve(path, params)
      attempts = 0
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        attempts += 1
        request_payload(path, params)
      rescue Faraday::Error, JSON::ParserError, Unavailable => e
        retry if attempts < 2

        Rails.logger.warn("NOAA request failed path=#{path} error=#{e.class}")
        raise Unavailable, 'NOAA is temporarily unavailable. Please try again.'
      ensure
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        Rails.logger.info(
          "NOAA request path=#{path} attempts=#{attempts} duration=#{duration.round(3)}"
        )
      end
    end

    def request_payload(path, params)
      remaining = @deadline ? @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC) : 10
      raise Unavailable, 'NOAA request time limit reached.' if remaining <= 0

      response = @connection.get(path, params) do |request|
        request.options.timeout = [remaining, 5].min
        request.options.open_timeout = [remaining, 2].min
      end
      raise Unavailable, 'NOAA is temporarily unavailable. Please try again.' if
        response.status == 429 || response.status >= 500
      raise NoData, 'NOAA has no data for this request.' unless response.success?

      payload = JSON.parse(response.body)
      raise Unavailable, 'NOAA returned an unreadable response.' unless payload.is_a?(Hash)
      raise NoData, 'NOAA has no data for this station and period.' if payload['error']

      payload
    end
  end
end
