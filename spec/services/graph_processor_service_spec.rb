require 'rails_helper'
require 'open-uri'

RSpec.describe GraphProcessorService, type: :service do
  valid_station_metadata = File.read File.join(File.dirname(__FILE__), 'fixtures', 'valid_station_metadata.json')

    context 'with a valid station metadata' do
      it 'should return the graph object' do
        p valid_station_metadata
      end
    end




end
