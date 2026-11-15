# NOAA planning and additional station products

The explorer retains the immutable station inventory. Capability discovery enriches the public catalog at read time using NOAA's `waterlevelsandmet&expand=sensors` and `1minute` metadata collections, cached for six hours. No schema change or catalog rewrite is required. Failed discovery retains station search and marks capabilities unconfirmed.

Purple plus pins identify confirmed additional products beyond the original observations, tide predictions and weather graphs: one-minute observations, conductivity, salinity/specific gravity, visibility, bridge-to-water clearance, OFS water-level forecast guidance and high-tide flooding outlooks. Purple clusters show both total stations and an explicit extra-product count; they draw above ordinary clusters. The map legend has a one-click additional-products-only filter, synchronized with the station layer dropdown. Orange means no confirmed extra products, not a guarantee that no other NOAA data exists. Advertised capability does not guarantee a recent reading.

## Planning and history

`GET /stations/:id/report` accepts `hours=24|48|72|168|720`, `future_hours=0|24|72|168|720` and `units=english|metric`. The UI defaults to 48 hours of history and seven days of future tides. Past and future requests are separate so the combined window never exceeds NOAA's per-request month limit. Future predictions have a separate chart and a high/low calendar. Subordinate prediction stations remain discrete high/low events; no continuous curve or interpolated departure is invented.

Observed-minus-predicted values are calculated only for exact matching timestamps in the same requested datum and units. Missing values and flagged observations remain gaps. This is a difference from the astronomical prediction, not attribution of the difference to a particular cause. Great Lakes stations retain their IGLD elevation explanation and do not acquire fictitious astronomical tides.

History, planning, units and timezone controls update graphs in place, preserve scroll position and update shared URL parameters. Measurement tables load on demand with bounded initial rows and a show-more control. New charts also have on-demand measurement tables. All displayed timestamps follow browser/station/UTC selection; NOAA daily flood-outlook dates remain calendar dates.

## Optional products

`GET /stations/:id/context?units=english|metric` independently requests advertised OFS guidance within the next 48 hours, one-minute preliminary observations for the past 24 hours, a seven-day high-tide flooding outlook where available, and links to other published NOAA station products. Each optional request can fail without replacing the main report. A retry control reloads additional products without re-fetching the core report.

OFS uses the same datum as the observed chart, including IGLD where NOAA supports it. The high-tide flooding endpoint explicitly requests MLLW and the selected units; its NOS minor threshold is labelled with that reference and the model's update date. Raw MDAPI flood thresholds do not declare their reference, so they are not blindly plotted on an MLLW/IGLD chart. Outlook likelihoods are not weather watches or warnings. An empty outlook is unavailable data, not a zero flood likelihood.

The sensor adapter supports every documented scalar CO-OPS station observation product represented here: wind/gust/direction, air/water temperature, pressure, humidity, conductivity, derived salinity/specific gravity, visibility and air gap. Disabled instruments are not queried; an enabled duplicate sensor takes precedence. Unsupported instrument names (for example an unspecified analog channel) are not mapped to invented API products. Other NOAA web products remain accessible through validated HTTPS NOAA links.

`GET /stations/:id/nearby?hours=...&units=...` uses NDBC's active XML catalog and standard meteorological text feeds. It examines at most three reporting buoys within 200 km, ordered by great-circle distance. Fixed shore instruments are excluded. Names, coordinates, source links, distance, latest measurement and stale status identify each buoy as a separate location. Wave height/period/direction, wind/gust/direction, temperatures and pressure are graphed when present. Buoy charts load when expanded. Missing columns and `MM` values remain absent/gaps; SI heights, speeds and temperatures are converted explicitly for US displays. A nearby buoy is not claimed to represent the selected harbor's conditions.

Station IDs and request options are validated before outbound access. CO-OPS and NDBC clients use fixed official origins and fixed path templates, bounded timeouts and cached responses. NDBC paths accept only five-character station IDs, XML parsing disables network access, and responses have a size limit. Incoming NOAA product URLs are never fetched by the server; only approved NOAA HTTPS links are shown. No credentials or user coordinates are sent by these new services.

## Validation

RSpec checks exact-time differences, zero/null/quality handling, bounded planning windows, IGLD, conditional capabilities, malformed/upstream failures, safe product links, buoy selection/parsing/conversion and input validation. Browser regressions cover purple clusters/counts/filtering, future and longer history, no reload/scroll, optional failures/retry, extra sensor units, buoy graphs and timezone propagation. Fixtures never call NOAA or use production databases. Hosted checks separately verify real services and maps.

Live read-only verification on November 14, 2026 found 324 of 3,644 saved locations advertising at least one additional supported product: 253 one-minute, 160 model forecasts, 109 flooding outlooks, 26 conductivity/salinity/specific gravity, 21 visibility and 21 air gap. These are discovery counts, not guaranteed current readings; counts change as NOAA updates metadata. Hilo returned future tides, differences and flooding outlooks; Duluth returned IGLD model guidance; Sewells Point returned conductivity/salinity; buoy 51206 returned Hilo-area waves.

Sources: [CO-OPS Data API](https://api.tidesandcurrents.noaa.gov/api/prod/), [response fields](https://api.tidesandcurrents.noaa.gov/api/prod/responseHelp.html), [Metadata API](https://api.tidesandcurrents.noaa.gov/mdapi/prod/), [Derived Product API](https://api.tidesandcurrents.noaa.gov/dpapi/prod/), [NDBC measurement definitions](https://www.ndbc.noaa.gov/faq/measdes.shtml), [NDBC public data guide](https://www.ndbc.noaa.gov/docs/ndbc_web_data_guide.pdf).

Security review: [Puma advisories and NDBC streaming assessment](noaa-products-security.md). The release updates Puma 8.0.2 to 8.1.0 to include the published security fixes.
