require 'rails_helper'


RSpec.describe GraphProcessorService, type: :service do
  let(:station_id) { 8419317 }

  context 'with a valid station metadata' do
    it 'returns the graph object' do
      expect(
        GraphProcessorService::GraphProcessor
        .graph_constructor(station_id)
      ).to be_an_instance_of(
        LazyHighCharts::HighChart
      )
    end
  end
end
