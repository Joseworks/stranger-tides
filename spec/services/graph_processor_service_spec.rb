# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphProcessorService, type: :service do
  let(:station_id) { 9_461_380 }

  context 'with a valid station metadata' do
    it 'returns the graph object' do
      expect(
        GraphProcessorService::GraphProcessor
        .graph_constructor(station_id).instance_of?(
          LazyHighCharts::HighChart
        )
      ).to be(true)
    end
  end
end
