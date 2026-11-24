# frozen_string_literal: true

Rails.application.routes.draw do
  get 'show_stations' => 'stations#show_stations'
  post 'show_graph' => 'stations#show_graph'
  get 'health/catalog' => 'health#catalog'
  get 'stations.json' => 'stations#catalog'
  get 'stations/:id/report' => 'stations#report', as: :station_report
  get 'stations/:id/history' => 'stations#history'
  get 'stations/:id/context' => 'stations#context'
  get 'stations/:id/nearby' => 'stations#nearby'
  root 'stations#show_stations'
end
