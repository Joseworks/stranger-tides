require 'rails_helper'

RSpec.describe StationConstructor, type: :model do

  describe StationConstructor do
    station_id = 8454000
    current_station_data_range = StationDataRangeConstructor.new(station_id).range_constructor
    constructed_station = StationConstructor.new(current_station_data_range)

    response_as_json =constructed_station.url_constructor.as_json
      subject {response_as_json}
      it { is_expected.to include('metadata')}

    subject{URI(constructed_station.url_constructor)}
      it { is_expected.to be_an_instance_of(String) }
      it { should be_a(String) }
      it { should be_a_kind_of(String) }

    response = Net::HTTP.get(constructed_station.url_constructor)
      subject {response}
      it { is_expected.to be_an_instance_of(String) }
      it { is_expected.to include('8454000')}
  end
end
