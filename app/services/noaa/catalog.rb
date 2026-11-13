# frozen_string_literal: true

module Noaa
  class Catalog
    SNAPSHOT_NAME = 'NOAA catalog v1'
    PATH = '/mdapi/prod/webapi/stations.json'
    ID = /\A[a-zA-Z0-9]{6,7}\z/
    TYPES = %w[waterlevels tidepredictions waterlevelsandmet].freeze

    def initialize(client: Client.new)
      @client = client
    end

    def snapshot
      return @snapshot if defined?(@snapshot)

      @snapshot = Station.where(station_name: SNAPSHOT_NAME).order(:id).last
    end

    def stations
      return snapshot.metadata.fetch('stations') if snapshot

      # Older deployments keep the entire inventory in one named row.
      legacy = Station.find_by(station_name: 'All stations')
      Array(legacy&.metadata).filter_map { |row| legacy_station(row) }
    end

    def find(id)
      raise NoData, 'Choose a valid station.' unless ID.match?(id.to_s)

      stations.find { |station| station['station_id'] == id.to_s } ||
        raise(NoData, 'This station is not in the current catalog.')
    end

    def status
      record = snapshot
      { refreshed_at: record&.metadata&.fetch('retrieved_at', nil),
        stale: record.nil? || Time.iso8601(record.metadata.fetch('retrieved_at')) < 2.days.ago }
    end

    def refresh(apply: false, allow_removals: false)
      retrieved_at = Time.current.iso8601(6)
      rows = CatalogLoader.new(@client).call
      result = CatalogPublisher.new(rows, retrieved_at:).call(apply:, allow_removals:)
      remove_instance_variable(:@snapshot) if defined?(@snapshot)
      result
    end

    private

    def legacy_station(row)
      return unless row.is_a?(Hash) && ID.match?(row['station_id'].to_s)

      row.merge('station_id' => row['station_id'].to_s, 'state' => row.fetch('state', ''),
                'capabilities' => row.fetch('capabilities', ['waterlevels']))
    end
  end
end
