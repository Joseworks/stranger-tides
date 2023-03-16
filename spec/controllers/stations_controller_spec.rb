# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StationsController do
  let(:valid_attributes) do
    { station_name: 'All stations',
      tide_info: '{9461710,9454050,9452210,9457292,9462450,9463502}',
      metadata: [
        {
          station_id: '9461710',
          station_name: 'Atka',
          latitude: '52.2317',
          longitude: '-174.1730'
        },
        {
          station_id: '9454050',
          station_name: 'Cordova',
          latitude: '60.5583',
          longitude: '-145.7530'
        },
        {
          station_id: '9452210',
          station_name: 'Juneau',
          latitude: '58.2983',
          longitude: '-134.4120'
        },
        {
          station_id: '9462450',
          station_name: 'Nikolski',
          latitude: '52.9406',
          longitude: '-168.8713'
        },
        {
          station_id: '9463502',
          station_name: 'Port Moller',
          latitude: '55.9900',
          longitude: '-160.5620'
        }
      ] }
  end

  let(:invalid_attributes) do
    { station_name: 'Nothing',
      tide_info: '{9461710,9454050,9452210,9457292,9462450,9463502}',
      metadata: [
        {
          station_id: '',
          station_name: 'Atka',
          latitude: '52.2317',
          longitude: '-174.1730'
        },
        {
          station_id: '9454050',
          station_name: '',
          latitude: '60.5583',
          longitude: '-145.7530'
        },
        {
          station_id: '9452210',
          station_name: 'Juneau',
          latitude: '',
          longitude: '-134.4120'
        },
        {
          station_id: '9462450',
          station_name: 'Nikolski',
          latitude: '52.9406',
          longitude: ''
        },
        {
          station_id: '',
          station_name: '',
          latitude: '',
          longitude: ''
        }
      ] }
  end

  describe 'GET #show_stations' do
    it 'assigns the last station as @station' do
      station = Station.create! valid_attributes
      get :show_stations, params: { id: station.to_param }
      expect(assigns(:station)).to eq(station)
    end
  end

  describe 'GET #show_graph' do
    let(:params) do
      { content: 1_617_433,
        controller: 'stations',
        action: 'show_graph' }
    end

    it 'displays the graph' do
      post(:show_graph, params: params, format: :js)
      expect(response).to have_http_status(:success)
    end
  end
end
