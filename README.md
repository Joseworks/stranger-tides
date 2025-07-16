[![Maintainability](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/maintainability)](https://codeclimate.com/github/Joseworks/stranger-tides/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/29184c02a0f52a69800c/test_coverage)](https://codeclimate.com/github/Joseworks/stranger-tides/test_coverage)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-community-brightgreen.svg)](https://rubystyle.guide)

See the live version: [stranger-tides.com](https://www.stranger-tides.com/)

> **Note:** This project is not affiliated with NOAA, COOPS, NWLON, or any government institution. Data is for demonstration only.

---

## Table of Contents
- [About](#about)
- [Quick Start](#quick-start)
- [System Dependencies](#system-dependencies)
- [Database](#database)
- [Usage](#usage)
- [Rake Tasks](#rake-tasks)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

---

## About
This app displays NOAA real-time tide stations on a Google Map. Clicking a station shows the last 24 hours of tide data. Station data is loaded from a text file (see `data/station_list.txt`) and metadata is parsed and stored in the database.

---

## Quick Start

```sh
# Clone the repo
 git clone https://github.com/Joseworks/stranger-tides.git
 cd stranger-tides

# Install dependencies
 bundle install

# Set up the database
 rails db:create db:migrate

# (Optional) Seed or process station data
 rake stations_id_list:process_station_list
 rake station_list:retrieve_all_stations_metadata

# Start the server
 rails server
```

---

## System Dependencies
- Ruby 3.3.7
- Rails 7.0.4.3
- PostgreSQL
- Node.js (for JS assets)
- [Puma](https://github.com/puma/puma) (web server)
- [Foreman](https://github.com/ddollar/foreman) (Procfile manager)
- [gon](https://github.com/gazay/gon) (JS data sharing)
- [Rspec](https://rspec.info/) (testing)
- [CircleCI](https://circleci.com/) (CI/CD)

---

## Database
- Uses PostgreSQL
- Station metadata is stored as a `jsonb` column for efficient querying

---

## Usage
- Visit the app in your browser (default: http://localhost:3000)
- Click a station on the map to view tide data

---

## Rake Tasks
- `rake stations_delete:delete_station_list` — Delete all station info
- `rake stations_id_list:process_station_list` — Load station list from file
- `rake station_list:retrieve_all_stations_metadata` — Fetch and store station metadata
- `rake highcharts:update` — Update HighCharts assets

---

## Testing
- Run all tests:
  ```sh
  bundle exec rspec
  ```
- Code style:
  ```sh
  rubocop
  ```
- Security:
  ```sh
  bundle audit
  bundle exec brakeman
  ```

---

## Deployment
- Use the provided Rake tasks to prepare data
- Deploy to your preferred platform (Heroku, Render, etc.)
- Ensure environment variables and DB are configured

---

## Contributing
1. Fork the repo and create your branch from `main`
2. Run tests and Rubocop before submitting PRs
3. Open an issue for major changes
4. All contributions welcome!

---

## License
Copyright (c) 2015 [Jose C Fernandez](https://www.joseworks.org/) — MIT License

---

## Stargazers over time
[![Stargazers over time](https://starchart.cc/Joseworks/stranger-tides.svg?variant=adaptive)](https://starchart.cc/Joseworks/stranger-tides) 
