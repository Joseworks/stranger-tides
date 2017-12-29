[![Maintainability](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/maintainability)](https://codeclimate.com/github/Joseworks/stranger-tides/maintainability)

[![Test Coverage](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/test_coverage)](https://codeclimate.com/github/Joseworks/stranger-tides/test_coverage)


* ### See the live version on [stranger-tides.com](http://www.stranger-tides.com/)

Note:  Specs, testing and development still in progress.
       This code/site/code has no affiliation whatsoever with NOAA, COOPS (Center for Operational Oceanographic Products and Services), NWLON (National Water Level Observation Network ) or any other government institutions.

* Ruby version 2.2.3
* Rails version 4.2.4

* System dependencies

 - Unicorn as a web server
 - Foreman as a manager for Procfile-based applications
 - Lazy high charts
 - gon
 - Rspec


* Database
 - PostgreSQL

* How to run the test suite
 - rspec spec

Please feel free to use a different markup language if you do not plan to run
<tt>rake doc:app</tt>.


* Scope:
The app is intended to display NOAA real time reporting tide stations in a map rendered by Google maps Javascript API. Once clicked on the map, it should render the last 24 hrs for tide level information retrieved., including current level.

In order to achieve that, a rake process will read all the current tide stations from a txt file ( station_list.txt). This is necessary because at the time the app is being written NOAA does not provide an online service or list that can be retrieved in any other way than 'scraping' the information of a website. I am considering to write an small JSON API to hold this data.

### There are three rake tasks:

 - rake station_list:delete_station_list
  Delete all of the stations information from the database

 - rake station_list:process_station_list
  Reads the list of all stations from station_list.txt, and saves a single row in the database with a tide_info array of text containing all of the reporting stations id's:

  SELECT  "stations".* FROM "stations"  ORDER BY "stations"."id" DESC LIMIT 1
 => ["9461380", "9461710",...]


- rake station_list:retrieve_all_stations_metadata # Run Process

Reads the list of all stations from station_list.txt, and appends to the record saved by the above process another single row with a JSON field (metadata) that stores all of the stations metadata, eg:

  {"station_id"=>"9461380",
   "station_name"=>"Adak Island",
   "latitude"=>"51.8633",
    "longitude"=>"-176.6320"}

This rake task uses the TideParsingService, and prevents inconsistent data if an station in particular is not reporting tide levels. It also parses the parameters 's' and the timestamps for this readings.



* Deployment instructions
rake stations_delete:delete_station_list          # Delete Station List
rake stations_id_list:process_station_list        # Station List
rake station_list:retrieve_all_stations_metadata  # Process metadata



Note from NOAA: These raw data have not been subjected to the National Ocean Service's quality control or quality assurance procedures and do not meet the criteria and standards of official National Ocean Service data. They are released for limited public use as preliminary data to be used only with appropriate caution.
Source: [NOAA Tides and Currents](https://tidesandcurrents.noaa.gov/waterlevels.html?id=8724580)

* Passages Routing
This Rails Engine adds the ability to search over different attributes of Ruby on Rails routes within an application.

For example, an internal (or very permissive external) API can now expose a single page that will answer simple questions like: "What was the HTTP verb for the /users/clear_password route?" or "Does a v2 or v3 version for this route exist?".

Once the local server is up, append `'passages` to the url, when asked about authentication use:

username=username
password=password


Copyright (c) 2015 Jose C Fernandez released under the MIT license
