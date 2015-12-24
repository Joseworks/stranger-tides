test:
	bundle exec rspec
migrate:
	rake db:migrate
	bundle exec rake db:migrate RAILS_ENV=test
wipe:
	bundle exec rake db:drop db:setup
db:
	heroku pg:psql --app=stranger-tides
open:
	heroku open --app=stranger-tides
backup:
	heroku pg:backups capture --app stranger-tides
	curl -o pg-production-latest.dump 'heroku pg:backups public-url --app stranger-tides'
	bzip2 pg-production-latest.dump
deploy:
	heroku maintenance:on --app=stranger-tides
	git tag production_release_`date +"%Y%m%d-%H%M%S"`
	git push --tags
	git push heroku master
	heroku run rake db:migrate --app=stranger-tides
	heroku rake station_list:delete_station_list
	heroku rake station_list:process_station_list
	heroku rake station_list:process_all_stations
	heroku maintenance:off --app=stranger-tides
local-rake:
	rake db:migrate
	rake station_list:delete_station_list
	rake station_list:process_station_list
	rake station_list:process_all_stations
