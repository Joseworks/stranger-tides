# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GraphProcessorService, type: :service do
  let(:station_id) { '1617433' }
  let(:host) { 'api.tidesandcurrents.noaa.gov' }
  let(:path) { '/api/prod/datagetter' }
  let(:current_product) { 'water_level' }
  let(:station_name) { 'Kawaihae' }
  # let(:datum) { 'GL_LWD' }
  let(:query_params) do
    {
      application: 'NOS.COOPS.TAC.WL',
      begin_date: 2.days.ago.strftime('%Y%m%d'),
      datum: datum,
      end_date: Time.zone.now.strftime('%Y%m%d'),
      format: 'json',
      product: 'water_level',
      station: station_id,
      time_zone: 'gmt',
      units: 'english'
    }
  end

  let(:url) do
    "https://#{host}#{path}?application=#{
        query_params[:application]
      }&begin_date=20230603&datum=#{
        query_params[:datum]
      }&end_date=#{
        query_params[:end_date]
      }&format=#{
        query_params[:json]
      }&product=#{
        query_params[:water_level]
      }&station=#{
        query_params[:station_id]
      }&time_zone=#{
        query_params[:time_zone]
      }&units=#{
        query_params[:units]
      }"
  end
  let(:tide_levels) { (49..164).to_a.shuffle!.map { |s| s / 1000.0 } }

  context 'with valid station metadata' do
    context 'with a single datum of MLLW' do
      let(:datum) { 'MLLW' }

      before do
        allow(TideParsingService::TideProcessor)
          .to receive(:datum_retrieval)
          .with(station_id)
          .and_return(['MLLW'])

        allow(TideParsingService::TideProcessor).to receive_messages(url_validator: nil,
                                                                     tide_s_retrieval: tide_levels)
      end

      it 'returns the graph object' do
        expect(
          GraphProcessorService::GraphProcessor.new(station_id).call.instance_of?(
            LazyHighCharts::HighChart
          )
        ).to be(true)
      end
    end

    context 'with a datum array including MSL' do
      let(:datum) { %w[MSL DLQ] }

      before do
        allow(TideParsingService::TideProcessor)
          .to receive(:datum_retrieval)
          .with(station_id)
          .and_return(%w[MSL DLQ])

        allow(TideParsingService::TideProcessor).to receive_messages(url_validator: nil,
                                                                     tide_s_retrieval: tide_levels)
      end

      it 'returns the graph object' do
        expect(
          GraphProcessorService::GraphProcessor.new(station_id).call.instance_of?(
            LazyHighCharts::HighChart
          )
        ).to be(true)
      end
    end

    context 'with a datum array including MLLW' do
      let(:datum) { %w[MLLW MHW] }

      before do
        allow(TideParsingService::TideProcessor)
          .to receive(:datum_retrieval)
          .with(station_id)
          .and_return(%w[MLLW MHW])

        allow(TideParsingService::TideProcessor).to receive_messages(url_validator: nil,
                                                                     tide_s_retrieval: tide_levels)
      end

      it 'returns the graph object' do
        expect(
          GraphProcessorService::GraphProcessor.new(station_id).call.instance_of?(
            LazyHighCharts::HighChart
          )
        ).to be(true)
      end
    end
  end
end
