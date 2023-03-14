# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StationConstructor do
  describe StationConstructor do
    station_id = 8_454_000
    datum = 'MLLW'
    current_station_data_range = StationDataRangeConstructor.new(station_id,
                                                                 datum).range_constructor
    constructed_station = described_class.new(current_station_data_range)

    # it { is_expected.to include('metadata') }

    subject { Net::HTTP.get(constructed_station.url_constructor) }

    it { is_expected.to be_an_instance_of(String) }

    # response = Net::HTTP.get(constructed_station.url_constructor)

    it { is_expected.to include('8454000') }
  end
end
