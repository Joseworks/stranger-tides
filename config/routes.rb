Rails.application.routes.draw do
  mount Passages::Engine, at: '/passages'
  get 'show_stations' => 'stations#show_stations'
  post 'show_graph' => 'stations#show_graph'
  root 'stations#show_stations'
end
