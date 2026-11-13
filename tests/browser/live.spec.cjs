// Public, read-only smoke checks. No settings, catalogs or station data are changed.
const { test, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const targets = {
  production: process.env.PRODUCTION_URL || 'https://stranger-tides.com/',
  staging: process.env.STAGING_URL || 'https://stranger-tides-staging.herokuapp.com/'
};
async function inventory(page, url) {
  await page.goto(url);
  if (await page.locator('#station-explorer').count()) {
    const response = await page.request.get(new URL('/stations.json', url).href);
    expect(response.ok()).toBe(true);
    const payload = await response.json();
    return payload.stations;
  }
  return page.evaluate(() => gon.all_station_metadata.map(s => ({ ...s, capabilities: ['waterlevels'] })));
}
for (const [name, url] of Object.entries(targets)) {
  test(`${name}: real Maps and coastal/Great Lakes station data`, async ({ page }, info) => {
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    const stations = await inventory(page, url);
    expect(stations.length).toBeGreaterThan(0);
    await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible({ timeout: 30000 });
    const modern = await page.locator('#station-explorer').count();
    const results = [];
    for (const [id, stationName, datum] of [['9414290', 'San Francisco', 'MLLW'], ['9099064', 'Duluth', 'IGLD']]) {
      if (modern) {
        await page.getByLabel('Find a station', { exact: true }).fill(id);
        await page.locator(`#station-results button[data-station-id="${id}"]`).click();
        await expect(page.locator('#graph-partial .highcharts-title')).toHaveText(stationName, { timeout: 30000 });
        await expect(page.locator('#station-summary')).toContainText(`Height reference: ${datum}`);
        await expect(page.locator('.highcharts-container')).toHaveCount(1);
        const state = await page.evaluate(() => ({
          samples: chart_graph_partial.series[0].getColumn('y').length,
          series: chart_graph_partial.series.map(s => s.name), highcharts: Highcharts.version
        }));
        expect(state.samples).toBeGreaterThan(10); results.push({ id, datum, ...state });
      } else {
        const marker = page.getByRole('button', { name: `${stationName} ${id}`, exact: true });
        await marker.focus(); await marker.press('Enter');
        await expect(page.locator('#graph-partial .highcharts-title').last()).toContainText(stationName, { timeout: 30000 });
        results.push({ id, legacyGraphContainers: await page.locator('#tide-graph').count() });
      }
    }
    await page.screenshot({ path: info.outputPath(`${name}-chart.png`), fullPage: true });
    if (modern) {
      await page.getByRole('button', { name: 'Close station details' }).click();
      await expect(page.locator('#station-panel')).toBeHidden();
    }
    await fs.writeFile(info.outputPath(`${name}.json`), JSON.stringify({ url, stations, results, errors }, null, 2));
    expect(errors).toEqual([]);
  });
}

test('catalog comparison distinguishes intentional expansion from missing observing stations', async ({ page }, info) => {
  const production = await inventory(page, targets.production);
  const staging = await inventory(page, targets.staging);
  const activeStaging = staging.filter(s => s.capabilities.includes('waterlevels'));
  const ids = rows => new Set(rows.map(s => String(s.station_id)));
  const prodIds = ids(production), stageIds = ids(staging);
  const result = {
    productionCount: production.length, stagingCount: staging.length, stagingObservingCount: activeStaging.length,
    onlyProduction: production.filter(s => !stageIds.has(String(s.station_id))),
    onlyStaging: staging.filter(s => !prodIds.has(String(s.station_id)))
  };
  await fs.writeFile(info.outputPath('inventory-differences.json'), JSON.stringify(result, null, 2));
  // Observing coverage must be checked against NOAA, not a hard-coded historical count.
  const response = await page.request.get('https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=waterlevels');
  expect(response.ok()).toBe(true);
  const noaa = await response.json();
  expect(activeStaging.map(s => s.station_id).sort()).toEqual(noaa.stations.map(s => s.id).sort());
  // Opt in only when an identical inventory is expected; deliberate expansion is reported above.
  if (process.env.LIVE_REQUIRE_IDENTICAL_CATALOGS === '1') {
    expect(result.onlyProduction).toEqual([]); expect(result.onlyStaging).toEqual([]);
  }
});

test('www production has valid HTTPS and loads the app', async ({ page }) => {
  const response = await page.goto('https://www.stranger-tides.com/', { timeout: 20000 });
  expect(response.ok()).toBe(true);
  await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible({ timeout: 30000 });
});
