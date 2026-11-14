# frozen_string_literal: true

module Noaa
  class StationTimeZone
    DAYLIGHT = { -10 => 'America/Adak', -9 => 'America/Anchorage',
                 -8 => 'America/Los_Angeles', -7 => 'America/Denver',
                 -6 => 'America/Chicago', -5 => 'America/New_York',
                 -4 => 'Atlantic/Bermuda' }.freeze
    STANDARD = { -11 => 'Pacific/Pago_Pago', -10 => 'Pacific/Honolulu',
                 -4 => 'America/Puerto_Rico', 10 => 'Pacific/Guam',
                 12 => 'Pacific/Kwajalein' }.freeze

    def initialize(id, client:)
      @id = id
      @client = client
    end

    def call
      station = metadata(@id)
      offset = station['timezonecorr']
      daylight = station['observedst']
      if daylight.nil?
        reference = metadata(station['reference_id'])
        daylight = reference['observedst'] if reference['timezonecorr'] == offset
      end
      return DAYLIGHT[offset] if daylight == true
      return unless daylight == false && offset.is_a?(Numeric) && (-12..14).cover?(offset)

      STANDARD[offset] || ("Etc/GMT#{format('%+d', -offset)}" if offset == offset.to_i)
    rescue NoData, Unavailable
      nil
    end

    private

    def metadata(id)
      return {} unless Catalog::ID.match?(id.to_s)

      payload = @client.get("/mdapi/prod/webapi/stations/#{id}.json", {}, expires_in: 1.day)
      Array(payload['stations']).find { |row| row.is_a?(Hash) && row['id'] == id } || {}
    end
  end
end
