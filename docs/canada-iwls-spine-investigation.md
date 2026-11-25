# Canadian water-level services: IWLS and SPINE

Research branch `codex/canada-iwls-spine`, based independently on main. Investigated November25,2026. No Canadian data integration, credentials, paid subscription, database write or deployment is included.

## Recommendation

Start implementation with IWLS station discovery and available water-level observations/predictions. Add per-station forecasts and extra measurements through capability discovery. Treat SPINE as a separate St.Lawrence model layer, not a national station inventory. The map, station search, radial selection, current/history panels and time/unit controls can be reused, but provider identifiers, datums, quality codes, request budgets and attribution must remain distinct.

## Official sources

- [CHS service descriptions and request restrictions](https://tides.gc.ca/en/web-services-offered-canadian-hydrographic-service)
- [CHS data licence](https://tides.gc.ca/en/licence-agreement)
- [IWLS Swagger](https://api-iwls.dfo-mpo.gc.ca/swagger-ui/index.html?configUrl=/v3/api-docs/swagger-config)
- [SPINE Swagger](https://api-spine.dfo-mpo.gc.ca/swagger-ui/index.html)

## IWLS: countrywide station products

CHS describes IWLS as free under its licence. Available products include water-level observations, predictions and forecasts; station metadata/data holdings, benchmarks, height types and datum conversions; tide tables, statistics and photos. Certain sites also supply current speed/direction, temperature, salinity or dynamic bridge clearance. Availability must be discovered per station/series, not assumed from its presence on the map.

The official description lists nine endpoint families: station statistics, height types, tide tables, station metadata, data, stations, time-series definitions, benchmarks and phenomena. These map naturally onto station details, planning/history charts and the extra-product highlighting already present in Stranger Tides.

Published limits are3requests/second and30requests/minute per clientIP. Individual requests may span one week of1-minute data, three weeks of3-minute data, or one month for lower resolutions. A shared Heroku outboundIP can represent many users, so per-browser throttling alone is insufficient. Use a server-wide request budget, shared cache, bounded windows, cancellation and429 backoff. Avoid issuing every product request when opening each station; load additional products on demand and batch compatible queries.

Retain each sample's `qcFlagCode`:1means good,2means not evaluated/unknown,3means suspect. Never map2to verified or silently chart3as good. Preserve missing/flagged gaps, source timestamps and datum identity. Chart observed-minus-predicted only when series timestamps, units and vertical references are compatible; do not reuse NOAA MLLW or UK ODN assumptions for Canada.

## SPINE: a regional interpolated forecast

SPINE supplies interpolated forecasts for the St.Lawrence navigation-channel region between Montreal and Saint-Joseph-de-la-Rive. It is not a collection of additional coastal observation stations. Its documented30-day horizon combines approximately two days of hydrodynamic forecasts with28days of nonstationary prediction, adjusted using nearby observations.

Documented GET routes:

| Route | Inputs | Useful application behavior |
| --- | --- | --- |
| `/rest/v1/waterLevel` | Decimal latitude/longitude and UTC ISO8601 time; repeated coordinate/time triples supported | A clearly labelled forecast-at-location tool; batched chart samples after checking limits |
| `/rest/v1/boundarySpatial` | None | Show the supported model region rather than extrapolating globally |
| `/rest/v1/boundaryDate` | None | Bound the time picker using actual model availability |

The water-level response includes chart-datum elevation, calculation age in minutes and uncertainty (`precision`). Display all three; do not present interpolated model output as a measured tide-gauge reading. Preserve `DISTANCE_OUT_OF_RANGE` and `DATE_OUT_OF_RANGE` as clear empty/out-of-range states. A model-region badge/filter is more accurate than an “extra sensor” marker for SPINE.

## Cost, access and licence assessment

IWLS is explicitly described as free; no paid subscription or per-call tariff is advertised on the reviewed page. Neither reviewed service description requests an API key. The IWLS Swagger configuration was retrieved without a credential and identifies its v1 OpenAPI document at `/v3/api-docs/v1`. This establishes public documentation access, not a verified authentication contract for every data endpoint.

Full schema retrieval and the SPINE initializer failed local certificate-chain validation in both Python and curl. Certificate verification was kept enabled; no insecure requests or browser-warning bypass was attempted. Consequently, data-endpoint authentication, full response schemas, SPINE-specific quotas and exact available station counts remain unverified. Do not claim these live endpoints have been tested. Confirm the certificate chain in the intended deployment environment before implementing; do not weaken TLS to connect.

The CHS licence is materially different from the UK Open Government Licence: it prohibits navigation use and commercial/for-profit derivative products, and requires a prominent prescribed CHS/non-endorsement notice for permitted derivatives. Stranger Tides is branded as a JoseWorks demonstration, so confirm its intended public use is eligible before displaying CHS data. API access being free does not settle reuse permission. No licence-acceptance button was submitted during this investigation. This is a recorded implementation prerequisite, not a completed legal eligibility determination.

## Proposed delivery and acceptance

1. Verify TLS, endpoint auth, licence eligibility and attribution wording; capture versioned OpenAPI schemas and representative metadata fixtures.
2. Add a CHS provider with namespaced IDs and data-holding discovery. Show country/source and supported products; preserve NOAA and UK routes independently.
3. Normalize units, timestamps, datum and quality; add bounded observation/prediction/history graphs, CSV, photos and selected extra series. Implement the sharedIP rate budget before load testing.
4. Add SPINE coverage/time bounds and a separate forecast-at-location flow, with age, uncertainty, model identity and explicit out-of-range behavior.
5. Test request limits,429 recovery, stale/missing/suspect observations, datetime/datum conversions, asynchronous station changes, product-specific colors and desktop/phone layouts. Deploy to staging only after review.

Working estimate after access/reuse questions are settled:3–5development days for IWLS station observations/predictions on the current interface;1–2additional days for initial SPINE regional forecasts. Extra sensors, photos, datum conversion and extensive history add scope and should be sized after schema/series inventory is verified. These are implementation estimates, not a commitment to start Canadian code on this research branch.
