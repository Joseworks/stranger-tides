# frozen_string_literal: true

Rails.application.routes.draw do
  get 'show_stations' => 'stations#show_stations'
  post 'show_graph' => 'stations#show_graph'
  get 'stations.json' => 'stations#catalog'
  get 'stations/:id/report' => 'stations#report', as: :station_report
  root 'stations#show_stations'
end
