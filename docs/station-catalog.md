# Station catalog and explorer

The explorer reads observing, tide-prediction, and water-level/weather catalogs from NOAA's production Metadata API. Catalog types are capabilities, not interchangeable kinds of sensor. A prediction-only location must never be described as a live instrument. Currents are not included in this water-level explorer.

## Refreshing safely

Run a dry run first:

```sh
heroku run 'bin/rails stations:refresh' --app stranger-tides-staging
```

Publish validated additions and metadata updates:

```sh
heroku run 'bin/rails stations:refresh APPLY=1' --app stranger-tides-staging
```

Use Heroku Scheduler once daily, e.g. 07:00 UTC, with `bin/rails stations:refresh APPLY=1`. The task exits unsuccessfully on incomplete data, malformed records, concurrent publication, or suspicious product loss. The UI marks a catalog older than two days as overdue. Inspect scheduler failure logs rather than treating a stale badge as a successful refresh.

The Scheduler add-on is free; its one-off dynos consume usage. Staging uses its existing Eco hour pool. Do not provision a different dyno tier or paid scheduler as part of this change. Production scheduling must be configured only after the feature has passed staging and its security/review gate.

A removed ID requires a human to review the printed diff before running with `ALLOW_REMOVALS=1`. A reduction greater than 10% in any product is rejected even with that flag. The active-observing inventory is checked separately, so a larger prediction catalog cannot hide observation-station losses. Catalog membership is separate from whether a sensor has a fresh reading.

Each successful publication creates an immutable `NOAA catalog v1` row in the existing `stations` table. This works with production's existing integer ID/JSON schema: **no production migrations, schema load, reseed, deletion, or data restore is required**. Old named inventory rows are preserved. A transaction/advisory lock serializes publication, and an older fetch cannot overwrite a newer snapshot. New snapshots are selected explicitly, never through an unrelated `Station.last` row.

For rollback, inspect the snapshot IDs and run `bin/rails stations:rollback SNAPSHOT_ID=<id>` on the intended app after reviewing that snapshot. This appends the selected historical snapshot; it does not delete data. Pausing Scheduler is necessary if deliberately retaining an older catalog. Code rollback alone does not undo catalog changes. Historical builds using `Station.last` require special care: take the app into maintenance and restore the old named inventory selection before rolling code back; do not promote an old build blindly over a new snapshot.

Snapshots are retained for audit/rollback. Monitor database size; a retention/archive policy needs separate review before deleting history. Daily jobs should finish within one minute under normal NOAA responses. Repeated remote failures preserve the last good data.

## Station reports

`GET /stations.json` returns the saved catalog and its refresh age. `GET /stations/:id/report?hours=48&units=english` returns observations, predictions, the next day's predicted high/low events, available wind/temperature/pressure/humidity, datum, quality/flags, timestamps, and warnings. Allowed histories are 24/48/72 hours; units are `english` or `metric`. IDs must belong to the saved catalog. NOAA calls use only the official API origin, bounded retries and a 20-second report request budget. Stable datums are cached for a day; responses for a minute. Sensor metadata is cached for six hours: only enabled supported sensors are queried, and disabled instruments are identified with NOAA's explanation.

Measurements retain UTC epoch timestamps and null gaps. Real zeroes remain zero. Tide predictions are shown only for a published prediction capability. Harmonic stations offer continuous predictions; subordinate stations support high/low events only, shown as separate points without an interpolated tide curve. Great Lakes stations use published IGLD references rather than coastal high/low expectations. Their charts label lake elevation and explain how it differs from tide height; a selected-period range and variation make the actual change visible. Unsupported datums are explicit errors. Weather/prediction failures do not discard successful observations. The latest measurement is stale after 18 minutes; a successful HTTP request does not imply fresh observations.

Station names include the NOAA state code wherever available (for example, Duluth, MN) in search results, map labels, details, and chart titles. Existing state suffixes are not repeated. Locations with no published state retain their names.

Search and the station list remain available if Google Maps fails. Location is requested only after pressing the location button. Shareable URLs preserve station, history, units, and display time. Maps cluster dense markers, and Advanced Markers are used when `STRANGER_TIDES_MAP_ID` is configured; existing maps retain their compatible marker path without requiring new Cloud permissions. A real Maps smoke test is still required for either path.

The new interface uses JSON instead of executing server-generated AJAX JavaScript. Legacy `POST /show_graph` returns HTTP 410 with a reload instruction. Legacy source/tests remain for reference, but production manual import/delete tasks are disabled. Sprockets remains the active asset loader; the new explorer does not initialize Turbolinks or unused importmap scaffolding.

## Validation and rollout

Run RSpec against an isolated database, then `npm run test:browser` with a separate local database ending `_browser_test`. Browser tests exercise real Rails, JSON, assets, Highcharts, coastal/Great Lakes references, missing data, prediction-only stations, retry, cancellation, search, permission handling and focus restoration. Maps and NOAA are offline fixtures; hosted checks separately cover the real services. CI runs desktop/Android Chromium and iPhone WebKit, publishes coverage/browser artifacts and enforces 90% Ruby line / 70% branch coverage. Local macOS 13 uses installed Chrome; WebKit is validated in CI.

Deploy this branch directly to staging first. Initialize its catalog with the additive task only after checking the app name and verifying a successful dry run. Do not merge this feature into the dependency PR; the feature PR is stacked on its branch so each change remains reviewable. Production promotion requires latest exact-head reviews/security findings, green CI, staging validation, a fresh database backup, and explicit production rollout readiness. Do not use live inventory equality as a proxy for functional parity: the expanded catalog is an intentional data change, and NOAA readings vary with time.

NOAA sources: [Metadata API](https://api.tidesandcurrents.noaa.gov/mdapi/prod/), [Data API](https://api.tidesandcurrents.noaa.gov/api/prod/), [response/quality guide](https://api.tidesandcurrents.noaa.gov/api/prod/responseHelp.html). Current definitions supersede the repository's historical text files and deleted 2015 SOAP notes.
