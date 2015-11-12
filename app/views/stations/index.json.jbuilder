json.array!(@stations) do |station|
  json.extract! station, :id, :station_id, :station_name, :latitude, :longitude, :tide_info
  json.url station_url(station, format: :json)
end
