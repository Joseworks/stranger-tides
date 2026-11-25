# Free UK tide gauges

UK gauges use locally drawn Union flag map pins. The orange/purple outer pin still communicates the selected extra-product filter. Both Google Maps marker renderers use the same flag assets; selection enlarges the pin without changing its geographic anchor. NOAA markers retain their existing appearance, including stations in California (`CA`). Canadian stations are not integrated by this branch.

Branch: `codex/uk-tide-gauges`. No API key, subscription, paid dependency, database migration or catalog publication is needed. Production remains unchanged until separately reviewed and deployed.

Open Filters → Station network → United Kingdom — Environment Agency (or Both networks). UK links use `?network=uk&station=ea-E70039`. NOAA remains the default network. Provider-prefixed UK IDs avoid collisions with NOAA IDs. The shared map, nearby sorting, radial picker, Now/Tides/History panels, unit/time controls, tables and CSV export work with UK observations. The legend reads “Stations” and “Stations with Extra Sensors”.

## Data contract

- Official source: https://environment.data.gov.uk/flood-monitoring/doc/tidegauge . No registration or credential. Required attribution and Open Government Licence links appear when UK data are selected.
- Station catalog: `/flood-monitoring/id/stations?type=TideGauge&_limit=1000`. The published network description says44 locations. The live feed may contain a different number of sites; never hard-code44. On Nov25 the feed returned88 records across43 distinct labels, including paired local/national datums and two unsupported millimetre records. Prefer the national-datum record for each published site label. Do not treat slightly different coordinates on alternate-datum records as extra gauges.
- Many valid catalog entries omit operating status. Exclude explicit inactive entries, retain unknown-status entries and label that uncertainty in station details. Gauge freshness comes from actual observation timestamps, not catalog membership. Never claim missing-status entries are confirmed active.
- Readings are15-minute means in metres relative to Ordnance Datum Newlyn (`mAOD`, displayed ODN), or the station local datum if national datum is unavailable. These are elevations, not depth above the seabed. Retain zero/negative observations. Convert metres to feet using0.3048. Do not invent QC flags; quality is explicitly not supplied by this feed.
- UTC source times; display station time as `Europe/London` with automatic GMT/BST conversion. Observations normally lag15–30minutes; the UK stale threshold is45minutes. Break graph lines at missing15-minute intervals rather than applying NOAA's6-minute cadence.
- Current history choices24/48/72hours,7days,28days. Fixed dates are bounded to the rolling28UTCcalendar days, with15-minute resolution only. NOAA hourly/monthly resolutions, future predictions, observed/predicted departures, NOAA weather and photos are not supplied by this source and are hidden/rejected for UK IDs.

## Reliability and security

Server constructs requests only to fixed HTTPS Environment Agency paths using validated catalog IDs; upstream URLs are never fetched. Ten-second read/two-second connection limits, bounded response size/row count and cache keys include provider, date window and units. Successful catalog responses cache6hours and readings15minutes. Failed responses are not cached. Combined-network failure retains the available provider with a visible warning; network-switch generation checks prevent old catalog responses replacing newer choices. Existing station/readings/CSV cancellation guards remain in place. No coordinates are sent to the Environment Agency; nearby sorting remains local.

Changing network does not silently pan away from an open station. Selecting a UK station positions it through the existing selection flow. A UK home view centers the map on the UK. CSV retains machine-readable field names and explicit units/datum/source station ID.

## Verification

Service/request tests cover validation, duplicate datums, missing operating status, outages, numeric conversions, missing values and bounded history. Local browser scenarios exercise UK deep links,15-minute chart continuity, history/CSV, station timezone and switching back to NOAA. Existing NOAA regressions remain in the browser matrix. Real public Lowestoft data were checked separately from offline fixtures (189 observations in the checked48-hour window). Full exact-head CI/security review and staging acceptance remain prerequisites before merging.
