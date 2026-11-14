# Browser verification

`npm run test:browser` runs a real Rails server, Sprockets assets, jQuery AJAX and Highcharts against deterministic NOAA responses. A minimal Maps adapter replaces the external SDK for these tests only. No production code loads fixtures or enables WebMock. The test server refuses non-local databases and names not ending `_browser_test`, refuses unexpected existing data, and blocks external Ruby HTTP requests.

Use Ruby from `.ruby-version`, Node 22+, and a **new disposable local database**:

```sh
npm ci --ignore-scripts
npx playwright install chromium webkit
export DATABASE_URL=postgresql://localhost/stranger_tides_browser_test
RAILS_ENV=test bundle exec rails db:create db:schema:load
npm run test:browser
```

Schema loading is destructive to tables in its target database. Never use a Heroku URL for this command. It is not part of the test runner or a deployment step. CI supplies a newly created PostgreSQL service.

The suite covers desktop Chromium, Android Chrome emulation and iPhone WebKit emulation. It checks loaded marker images, denied location, granted location/recentering, station selection, numeric chart data, map resizing, replacement without duplicate charts, close, and reopening. These are viewport/browser-engine tests, not physical-device tests. CI keeps screenshots and traces on failures and the HTML report for seven days.

On macOS 13, current bundled browsers are unsupported. Use installed Chrome for local desktop/Android checks, then use the Ubuntu CI job for WebKit:

```sh
PLAYWRIGHT_CHANNEL=chrome npm run test:browser -- --project=desktop-chromium --project=mobile-chromium
```

## Hosted comparison

```sh
npm run test:live
```

This separate, manually invoked suite contacts the public production apex, staging and production `www` domains. It uses the real Maps SDK, keyboard-activates actual station markers, and requests coastal (San Francisco) and Great Lakes (Cleveland) charts through each application's real `/show_graph` endpoint. That POST renders a graph and does not write application data. It verifies titles, source, height units, populated numeric series, replacement, map resizing and close on desktop and Android viewports. It never deploys, modifies config, migrates or seeds a hosted database, or ignores TLS errors. It makes live NOAA requests; avoid running it in a rapid loop.

The suite also compares all public station IDs, names and coordinates. A data mismatch fails the parity check and saves details rather than silently accepting a changed station set. JSON results, screenshots, HTML reports and failure traces appear in `test-results/live` and `playwright-report/live`. Traces can include public page HTML, browser-visible Maps keys and request data; do not publish them to an unrelated service.

Live NOAA samples change with time, so numeric values and point counts are not treated as pixel snapshots. Exact rendered pixel equality is not expected between different Highcharts versions and map tile updates. Passing these tests establishes parity for the covered flows; it is not proof of every possible station or network-error scenario. RSpec separately covers the server's NOAA parsing and chart construction.

## Findings from 2026-11-12

- Production v264 remains deployed. Its apex map and live coastal/Great Lakes charts work. `www` times out through the resolver's forwarding IP; reaching Heroku routing directly with the proper SNI fails certificate verification. The `www` certificate expired 2026-03-13; Heroku reports `Incorrect DNS Settings`. Repair DNS at the registrar and then verify certificate renewal without bypassing HTTPS validation.
- Initial hosted inventory: 119 production stations, 303 staging stations; 2 production stations absent from staging, 186 additional staging stations, 82 shared stations with different names/coordinates. Staging was populated from today's public NOAA water-level metadata, whereas production holds older data. No production data was changed to make the comparison pass.
- The browser suite reproduced duplicate graph wrappers when selecting a second station without closing the first. The upgrade branch destroys/removes the prior chart before rendering its replacement.
- The initial staging custom image markers were optimized into a canvas, removing keyboard/button semantics. The upgrade branch uses the legacy SDK's documented `optimized: false` option so users and automated tests can activate markers with the keyboard. This retains the existing Maps integration; migration to Advanced Markers is separate work.

References: [Playwright API mocking](https://playwright.dev/docs/mock), [browser channels](https://playwright.dev/docs/browsers), [Google legacy marker accessibility](https://developers.google.com/maps/documentation/javascript/markers), [Heroku custom domains](https://devcenter.heroku.com/articles/custom-domains).

## Station explorer changes

The feature branch replaces the executable `/show_graph` response with the read-only JSON station-report API. Its deterministic suite now covers ten scenarios across three browser configurations (30 CI checks), including null gaps, prediction-only locations, IGLD, retries, delayed-response cancellation, deep links, unit/time changes, search and map failure. Existing Maps and NOAA credentials are never used by this offline suite.

Hosted checks recognize both the old production interface and the new explorer. They publish the full catalog difference and require staging's observing IDs to match NOAA's current active inventory. Exact production/staging inventory equality is optional via `LIVE_REQUIRE_IDENTICAL_CATALOGS=1`, because adding current stations and prediction locations is the intended feature. The production baseline's duplicate graph wrappers remain visible in diagnostics; they are not claimed as fixed until the new interface is deployed there.

See [catalog operations](../../docs/station-catalog.md) for staged refresh, rollback, monitoring, and deployment safeguards. Historical findings above describe the earlier upgrade baseline, including the subsequently repaired DNS/certificate incident.
