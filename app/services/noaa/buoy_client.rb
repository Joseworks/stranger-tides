# frozen_string_literal: true

module Noaa
  class BuoyClient
    ORIGIN = 'https://www.ndbc.noaa.gov'

    def initialize(cache: Rails.cache)
      @cache = cache
      @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 18
      @connection = Faraday.new(url: ORIGIN)
    end

    def get(path, expires_in: 10.minutes)
      raise NoData, 'Invalid buoy request.' unless
        path == '/activestations.xml' || %r{\A/data/realtime2/[a-z0-9]{5}\.txt\z}.match?(path)

      @cache.fetch(['ndbc-v1', path], expires_in:) do
        remaining = @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise Unavailable, 'Buoy request time limit reached.' if remaining <= 0

        body = +''
        response = @connection.get(path) do |request|
          request.options.open_timeout = [remaining, 2].min
          request.options.timeout = [remaining, 5].min
          request.options.on_data = stream_into(body)
        end
        raise Unavailable, 'NOAA buoy data is temporarily unavailable.' unless response.success?

        body
      end
    rescue Faraday::Error
      raise Unavailable, 'NOAA buoy data is temporarily unavailable.'
    end

    private

    def stream_into(body)
      proc do |chunk, _bytes|
        if body.bytesize + chunk.bytesize > 2.megabytes
          raise Unavailable, 'NOAA buoy response is too large.'
        end

        body << chunk
      end
    end
  end
end
