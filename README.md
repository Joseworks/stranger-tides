[![Maintainability](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/maintainability)](https://codeclimate.com/github/Joseworks/stranger-tides/maintainability)

[![Test Coverage](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/test_coverage)](https://codeclimate.com/github/Joseworks/stranger-tides/test_coverage)

[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

[![Ruby Style Guide](https://img.shields.io/badge/code_style-community-brightgreen.svg)](https://rubystyle.guide)

* ### See the live version on [stranger-tides.com](https://www.stranger-tides.com/)

Note:  Specs, testing, and development are still in progress.
       This code/site/code has no affiliation whatsoever with NOAA, COOPS (Center for Operational Oceanographic Products and Services), NWLON (National Water Level Observation Network ) or any other government institutions.

* Ruby version 3.2.1 
* Rails version 7.0.4.3

* System dependencies

 - Puma as a web server
 - Foreman as a manager for Procfile-based applications
 - Lazy high charts
 - gon
 - Rspec
 - Travis CI for continuous integration testing.

* Database
 - PostgreSQL

* How to run the test suite
 - rspec spec

Please feel free to use a different markup language if you do not plan to run
<tt>rake doc:app</tt>.


* Scope:
The app is intended to display NOAA real-time reporting tide stations in a map rendered by Google Maps Javascript API. Once clicked on the map, it should render the last 24 hrs for tide level information retrieved., including the current level.

To achieve that, a rake process will read all the current tide stations from a txt file ( station_list.txt). This is necessary because when the app is being written NOAA does not provide an online service or list that can be retrieved in any other way than 'scraping' the information of a website. I am considering writing a small JSON API to hold this data.

### There are three rake tasks:

 - rake station_list:delete_station_list
  Delete all of the stations information from the database

 - rake station_list:process_station_list
  Reads the list of all stations from station_list.txt, and saves a single row in the database with a tide_info array of text containing all of the reporting stations id's:

  SELECT  "stations".* FROM "stations"  ORDER BY "stations"."id" DESC LIMIT 1
 => ["9461380", "9461710",...]


- rake station_list:retrieve_all_stations_metadata # Run Process

Reads the list of all stations from station_list.txt, and appends to the record saved by the above process another single row with a JSON field (metadata) that stores all of the station's metadata, eg:

  {"station_id"=>"9461380",
   "station_name"=>"Adak Island",
   "latitude"=>"51.8633",
    "longitude"=>"-176.6320"}

This rake task uses the TideParsingService, and prevents inconsistent data if a station in particular is not reporting tide levels. It also parses the parameters 's' and the timestamps for these readings.



* Deployment instructions
rake stations_delete:delete_station_list          # Delete Station List
rake stations_id_list:process_station_list        # Station List
rake station_list:retrieve_all_stations_metadata  # Process metadata



Note from NOAA: These raw data have not been subjected to the National Ocean Service's quality control or quality assurance procedures and do not meet the criteria and standards of official National Ocean Service data. They are released for limited public use as preliminary data to be used only with appropriate caution.
Source: [NOAA Tides and Currents](https://tidesandcurrents.noaa.gov/waterlevels.html?id=8724580)

#### Update HighCharts
rake highcharts:update

Copyright (c) 2015 [Jose C Fernandez](https://www.joseworks.org/) released under the MIT license

## Stargazers over time
[![Stargazers over time](https://starchart.cc/Joseworks/stranger-tides.svg?variant=adaptive)](https://starchart.cc/Joseworks/stranger-tides) 
