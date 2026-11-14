# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StationConstructor do
  subject(:response_body) { Net::HTTP.get(constructed_station.url_constructor) }

  let(:station_params) { StationDataRangeConstructor.new(8_454_000, 'MLLW').range_constructor }
  let(:constructed_station) { described_class.new(station_params) }

  it { is_expected.to be_an_instance_of(String) }
  it { is_expected.to include('8454000') }
end
