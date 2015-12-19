require 'rails_helper'

RSpec.describe StationDataRangeConstructor, type: :model do
  context 'with valid station_id' do
    station_id = 1234567
    current_station = StationDataRangeConstructor.new(station_id)
    subject {current_station.range_constructor}

    it { is_expected.to have_key(:my_station)}
    it { is_expected.to have_key(:product)}
    it { is_expected.to have_key(:begin_date)}
    it { is_expected.to have_key(:begin_time)}
    it { is_expected.to have_key(:end_date)}
    it { is_expected.to have_key(:end_time)}
    it { is_expected.to have_key(:datum)}
    it { is_expected.to have_key(:units)}
    it { is_expected.to have_key(:time_zone)}
    it { is_expected.to have_key(:application)}
    it { is_expected.to have_key(:format)}
    it { is_expected.to include(my_station: 1234567)}
  end

  context 'with invalid station_id' do
    station_id = nil
    current_station = StationDataRangeConstructor.new(station_id)
    subject {current_station.range_constructor}
    it { is_expected.to have_key(:my_station)}
    it { is_expected.not_to include(my_station: 1234567)}
  end
end

