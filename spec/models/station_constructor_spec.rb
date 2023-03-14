require 'rails_helper'

RSpec.describe StationConstructor, type: :model do
  describe StationConstructor do
    station_id = 8454000
    datum = 'MLLW'
    current_station_data_range = StationDataRangeConstructor.new(station_id, datum).range_constructor
    constructed_station = StationConstructor.new(current_station_data_range)

    # it { is_expected.to include('metadata') }

    it { is_expected.to be_an_instance_of(String) }

    response = Net::HTTP.get(constructed_station.url_constructor)
    subject { response }

    # it { is_expected.to include('8454000') }
  end
end
