# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::HistoryReport do
  let(:station) do
    { 'station_id' => '9414290', 'station_name' => 'San Francisco',
      'capabilities' => %w[waterlevels tidepredictions], 'prediction_type' => 'H' }
  end
  let(:client) { Noaa::Client.new(cache: ActiveSupport::Cache::NullStore.new) }

  before do
    travel_to(Time.utc(2026, 11, 24, 18))
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: 'MLLW' }] }.to_json)
  end

  def report(first: '2020-01-01', last: '2020-01-02', **)
    described_class.new(station, begin_date: first, end_date: last, client:, **).call
  end

  def data(product, rows, **params)
    stub_request(:get, Noaa::Client::ORIGIN + Noaa::StationReport::DATA_PATH)
      .with(query: hash_including('product' => product, **params.stringify_keys))
      .to_return(body: { (product == 'predictions' ? :predictions : :data) => rows }.to_json)
  end

  it 'uses whole UTC days, keeps zeros and gaps, and compares matching unflagged times' do
    data('water_level', [
           { t: '2020-01-01 00:00', v: '0', q: 'v', f: '0,0,0,0' },
           { t: '2020-01-01 00:06', v: '', q: 'v', f: '0,0,0,0' },
           { t: '2020-01-02 23:54', v: '8', q: 'p', f: '1,0,0,0' },
           { t: '2020-01-03 00:00', v: '9' }
         ], begin_date: '20200101', end_date: '20200102', time_zone: 'gmt')
    data('predictions', [{ t: '2020-01-01 00:00', v: '1' },
                         { t: '2020-01-02 23:54', v: '7' }], interval: '6')
    result = report
    expect(result[:observations].pluck(:value)).to eq([0.0, nil, 8.0])
    expect(result[:differences].pluck(:value)).to eq([-1.0, nil, nil])
    expect(result[:window]).to include(product: 'water_level', resolution: 'six_minute')
  end

  it 'selects verified hourly heights and hourly predictions for longer periods' do
    data('hourly_height', [{ t: '2020-02-01 00:00', v: '2', f: '0,0' }],
         begin_date: '20200101', end_date: '20201230')
    data('predictions', [{ t: '2020-02-01 00:00', v: '1' }], interval: 'h')
    result = report(last: '2020-12-30')
    expect(result[:window]).to include(resolution: 'hourly', interval_minutes: 60)
    expect(result[:observations].first).to include(value: 2.0, quality: 'v')
    expect(result[:differences].first[:value]).to eq(1.0)
  end

  it 'normalizes full months and parses MSL, not a fictitious v field' do
    data('monthly_mean', [{ year: '2020', month: '1', MSL: '0', inferred: '0' },
                          { year: '2020', month: '2', MSL: '', inferred: '1' },
                          { year: 'bad', month: '1', MSL: '9' },
                          { year: '2021', month: '1', MSL: '99' }],
         begin_date: '20200101', end_date: '20201231')
    result = report(first: '2020-01-15', last: '2020-12-15', resolution: 'monthly')
    expect(result[:observations].pluck(:period, :value)).to eq([['2020-01', 0.0], ['2020-02', nil]])
    expect(result[:window]).to include(calendar_months: true, interval_minutes: nil)
    expect(result.values_at(:predictions, :differences)).to eq([[], []])
    expect(WebMock).not_to have_requested(:get, /datagetter/)
      .with(query: hash_including('product' => 'predictions'))
  end

  it 'chooses monthly means automatically for multi-year season comparisons' do
    data('monthly_mean', [])
    expect(report(last: '2021-01-01')[:window][:resolution]).to eq('monthly')
  end

  it 'preserves the Great Lakes height reference and does not request tides' do
    station['capabilities'] = ['waterlevels']
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: 'GL_LWD' }] }.to_json)
    data('hourly_height', [{ t: '2020-02-01 00:00', v: '602' }], datum: 'IGLD', units: 'metric')
    result = report(last: '2020-03-01', units: 'metric')
    expect(result).to include(datum: 'IGLD', units: 'metric', predictions: [], differences: [])
  end

  it 'keeps subordinate predictions as discrete events without differences' do
    station['capabilities'] = ['tidepredictions']
    station['prediction_type'] = 'S'
    data('predictions', [{ t: '2020-01-01 01:00', v: '2', type: 'H' }], interval: 'hilo')
    result = report
    expect(result).to include(observations: [], differences: [])
    expect(result[:predictions].first).to include(type: 'H')
    expect(WebMock).not_to have_requested(:get, /datums.json/)
  end

  it 'retains successful observations when predictions fail and reports the warning' do
    data('water_level', [{ t: '2020-01-01 00:00', v: '2' }])
    stub_request(:get, /datagetter/).with(query: hash_including('product' => 'predictions'))
                                    .to_return(status: 503)
    expect(report).to include(predictions: [], differences: [],
                              warnings: [hash_including(product: 'predictions')])
  end

  it 'distinguishes no historical data from upstream transport failures' do
    station['capabilities'] = ['waterlevels']
    stub_request(:get, /datagetter/).to_return(body: { error: { message: 'No data' } }.to_json)
    expect(report).to include(observations: [], warnings: [hash_including(product: 'water_level')])
    stub_request(:get, /datagetter/).to_return(status: 503)
    expect { report }.to raise_error(Noaa::Unavailable)
  end

  it 'rejects invalid, reversed, future and excessive ranges before contacting NOAA' do
    [{ first: nil }, { first: '2020-02-30' }, { first: '01/01/2020' },
     { first: '2021-01-01' }, { last: '2027-01-01' }, { first: '1799-12-31' },
     { first: '1800-01-01', last: '2000-01-01' },
     { last: '2020-01-31', resolution: 'six_minute' },
     { last: '2020-12-31', resolution: 'hourly' }, { resolution: 'bad' },
     { units: 'bad' }].each do |options|
      expect { report(**options) }.to raise_error(Noaa::NoData)
    end
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end
end
