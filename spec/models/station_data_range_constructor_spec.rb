# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StationDataRangeConstructor do
  context 'with valid station_id' do
    subject { described_class.new(1_234_567, 'MLLW').range_constructor }

    it { is_expected.to have_key(:my_station) }
    it { is_expected.to have_key(:product) }
    it { is_expected.to have_key(:begin_date) }
    it { is_expected.to have_key(:begin_time) }
    it { is_expected.to have_key(:end_date) }
    it { is_expected.to have_key(:end_time) }
    it { is_expected.to have_key(:datum) }
    it { is_expected.to have_key(:units) }
    it { is_expected.to have_key(:time_zone) }
    it { is_expected.to have_key(:application) }
    it { is_expected.to have_key(:format) }
    it { is_expected.to include(my_station: 1_234_567) }
    it { is_expected.to include(product: 'water_level') }
    it { is_expected.to include(format: 'json') }
  end

  context 'with invalid station_id' do
    subject { described_class.new(nil, 'MLLW').range_constructor }

    it { is_expected.not_to include(my_station: 1_234_567) }
  end
end
