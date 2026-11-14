# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Noaa::StationTimeZone do
  let(:client) { Noaa::Client.new(cache: ActiveSupport::Cache::NullStore.new) }

  def metadata(id, **fields)
    stub_request(:get, "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/#{id}.json")
      .to_return(body: { stations: [{ id:, **fields }] }.to_json)
  end

  it 'uses Hawaii time without daylight saving and Central time with daylight saving' do
    metadata('1612480', timezonecorr: -10, observedst: false)
    metadata('9099064', timezonecorr: -6, observedst: true)
    hawaii = described_class.new('1612480', client:).call
    central = described_class.new('9099064', client:).call
    offsets = lambda do |zone|
      [1, 7].map do |month|
        TZInfo::Timezone.get(zone).period_for_utc(Time.utc(2026, month)).utc_total_offset / 3600
      end
    end
    expect(offsets.call(hawaii)).to eq([-10, -10])
    expect(offsets.call(central)).to eq([-6, -5])
  end

  it 'distinguishes Aleutian daylight time from Hawaii despite their shared standard offset' do
    metadata('9461380', timezonecorr: -10, observedst: true)
    expect(described_class.new('9461380', client:).call).to eq('America/Adak')
  end

  it 'uses a prediction reference only when its published standard offset matches' do
    metadata('TWC0331', timezonecorr: -8, reference_id: '9414290')
    metadata('9414290', timezonecorr: -8, observedst: true)
    expect(described_class.new('TWC0331', client:).call).to eq('America/Los_Angeles')
  end

  it 'does not guess daylight saving from a reference in a different time zone' do
    metadata('TWC0331', timezonecorr: -5, reference_id: '9414290')
    metadata('9414290', timezonecorr: -8, observedst: true)
    expect(described_class.new('TWC0331', client:).call).to be_nil
  end

  it 'does not invent a zone when daylight-saving metadata is missing' do
    metadata('TWC0331', timezonecorr: -5)
    expect(described_class.new('TWC0331', client:).call).to be_nil
  end

  it 'uses fixed-offset IANA zones only when NOAA explicitly says daylight saving is not observed' do
    metadata('TWC0331', timezonecorr: -5, observedst: false)
    expect(described_class.new('TWC0331', client:).call).to eq('Etc/GMT+5')
  end

  it 'keeps station reports usable when optional time-zone metadata fails' do
    stub_request(:get, %r{/stations/1612480\.json}).to_return(status: 503)
    expect(described_class.new('1612480', client:).call).to be_nil
  end
end
