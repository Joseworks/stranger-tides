Rails.application.routes.draw do
  get 'show_station' => 'stations#show_station'
  get 'show_stations' => 'stations#show_stations'
  post 'show_graph' => 'stations#show_graph'
  root 'stations#show_station'
end
