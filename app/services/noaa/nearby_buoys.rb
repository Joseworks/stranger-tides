# frozen_string_literal: true

module Noaa
  class NearbyBuoys
    def initialize(station, units: 'english', hours: 48, client: BuoyClient.new)
      @station = station
      @units = units
      @hours = Integer(hours, exception: false)
      @client = client
      raise NoData, 'Choose a supported history and unit system.' unless
        StationReport::HOURS.include?(@hours) && %w[english metric].include?(units)
    end

    def call
      raise NoData, 'Station coordinates are unavailable.' unless coordinates?

      now = Time.current.utc
      @warnings = []
      @failed_buoys = []
      buoys = nearby.filter_map { |station| read_buoy(station, now) }
      { units: @units, hours: @hours, radius_km: 200, buoys:, warnings: @warnings,
        failed_buoys: @failed_buoys }
    end

    private

    def read_buoy(station, now)
      body = @client.get("/data/realtime2/#{station[:id]}.txt")
      series = BuoyData.new(units: @units, hours: @hours).parse(body, now)
      return if series.empty?

      valid = series.values.flatten.select { |point| point[:value] }
      latest = valid.max_by { |point| point[:timestamp] }
      station.merge(series:, latest_at: latest[:time],
                    stale: Time.iso8601(latest[:time]) < now - 2.hours,
                    source_url: "https://www.ndbc.noaa.gov/station_page.php?station=#{station[:id]}")
    rescue NoData, Unavailable => e
      @failed_buoys << station[:id] if e.is_a?(Unavailable)
      @warnings << "#{station[:id]}: #{e.message}"
      nil
    end

    def nearby
      xml = Nokogiri::XML(@client.get('/activestations.xml', expires_in: 6.hours)) do |config|
        config.strict.nonet
      end
      raise Unavailable, 'NOAA buoy catalog is incomplete.' unless xml.root&.name == 'stations'

      rows = xml.xpath('/stations/station').filter_map { |node| normalize(node) }
      rows.sort_by { |station| station[:distance_km] }.first(3)
    rescue Nokogiri::XML::SyntaxError
      raise Unavailable, 'NOAA buoy catalog is unreadable.'
    end

    def coordinates?
      lat = Float(@station['latitude'], exception: false)
      lng = Float(@station['longitude'], exception: false)
      lat&.finite? && lng&.finite? && (-90..90).cover?(lat) && (-180..180).cover?(lng)
    end

    def active_buoy?(node)
      /\A[a-z0-9]{5}\z/.match?(node['id'].to_s) &&
        node['met'] == 'y' && node['type'] == 'buoy'
    end

    def normalize(node)
      return unless active_buoy?(node)

      latitude = Float(node['lat'], exception: false)
      longitude = Float(node['lon'], exception: false)
      return unless latitude&.finite? && longitude&.finite? &&
                    (-90..90).cover?(latitude) && (-180..180).cover?(longitude)

      km = distance(latitude, longitude)
      return unless km <= 200

      { id: node['id'], name: node['name'].to_s.first(200), latitude:, longitude:,
        distance_km: km.round(1) }
    end

    def distance(lat, lng)
      latitude = Float(@station.fetch('latitude'))
      longitude = Float(@station.fetch('longitude'))
      radians = Math::PI / 180
      a = (Math.sin((lat - latitude) * radians / 2)**2) +
          (Math.cos(lat * radians) * Math.cos(latitude * radians) *
          (Math.sin((lng - longitude) * radians / 2)**2))
      6371 * 2 * Math.asin(Math.sqrt(a.clamp(0, 1)))
    end
  end
end
