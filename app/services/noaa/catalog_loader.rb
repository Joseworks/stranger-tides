# frozen_string_literal: true

module Noaa
  class CatalogLoader
    def initialize(client)
      @client = client
    end

    def call
      all = {}
      Catalog::TYPES.each do |type|
        collection(type).each do |row|
          validate!(row)
          station = all[row['id']] ||= normalize(row)
          station['capabilities'] |= [type]
          station['state'] = row['state'].to_s if station['state'].blank?
        end
      end
      all.values.sort_by { |station| station['station_id'] }
    rescue NoData => e
      raise InvalidCatalog, e.message
    end

    private

    def collection(type)
      payload = @client.get(Catalog::PATH, { type: }, expires_in: 0.seconds)
      rows = payload['stations']
      raise InvalidCatalog, "Incomplete #{type} catalog." unless
        rows.is_a?(Array) && rows.any? && payload['count'] == rows.length
      raise InvalidCatalog, "Invalid #{type} catalog entries." unless rows.all?(Hash)
      raise InvalidCatalog, "Duplicate #{type} station IDs." unless
        rows.pluck('id').uniq.length == rows.length

      rows
    end

    def validate!(row)
      valid_id = row['id'].is_a?(String) && Catalog::ID.match?(row['id'])
      valid = valid_id && row['name'].is_a?(String) && row['name'].strip.present? &&
              row['name'].length <= 200
      raise InvalidCatalog, 'Invalid station metadata; keeping the previous catalog.' unless
        valid && coordinate?(row['lat'], -90..90) && coordinate?(row['lng'], -180..180)
    end

    def coordinate?(value, range)
      number = Float(value, exception: false)
      number&.finite? && range.cover?(number)
    end

    def normalize(row)
      { 'station_id' => row['id'], 'station_name' => row['name'],
        'latitude' => row['lat'].to_f, 'longitude' => row['lng'].to_f,
        'state' => row['state'].to_s, 'tidal' => row['tidal'], 'greatlakes' => row['greatlakes'],
        'capabilities' => [] }
    end
  end
end
