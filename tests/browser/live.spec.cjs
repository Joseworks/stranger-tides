// Public pages only. Graph POSTs render NOAA data; these endpoints do not write application data.
const { test, expect } = require('@playwright/test');
const fs = require('node:fs/promises');
const targets = {
  production: 'https://stranger-tides.com/',
  staging: 'https://stranger-tides-staging.herokuapp.com/'
};

async function inventory(page, url) {
  const response = await page.goto(url);
  expect(response.status()).toBe(200);
  await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible({ timeout: 30000 });
  return page.evaluate(() => gon.all_station_metadata.map(s => ({
    id: String(s.station_id), name: s.station_name, lat: Number(s.latitude), lng: Number(s.longitude)
  })).sort((a, b) => a.id.localeCompare(b.id)));
}
async function chartState(page) {
  return page.evaluate(() => {
    const chart = window.chart_graph_partial;
    const values = chart.series[0].yData ?? chart.series[0].getColumn('y');
    return {
      title: chart.title.textStr, subtitle: chart.subtitle.textStr,
      series: chart.series[0].name, unit: chart.yAxis[0].axisTitle.textStr,
      samples: values.length, numeric: values.every(Number.isFinite),
      first: chart.xAxis[0].categories[0], last: chart.xAxis[0].categories.at(-1),
      graphContainers: document.querySelectorAll('#tide-graph').length,
      highcharts: Highcharts.version
    };
  });
}
for (const [name, url] of Object.entries(targets)) {
  test(`${name}: real Maps, coastal/Great Lakes charts, replacement and close`, async ({ page }, info) => {
    const errors = [];
    const failedRequests = [];
    page.on('requestfailed', request => {
      const url = new URL(request.url());
      failedRequests.push({ url: url.origin + url.pathname, error: request.failure()?.errorText });
    });
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    const stations = await inventory(page, url);
    expect(stations.length).toBeGreaterThan(0);
    const results = [];
    for (const station of ['San Francisco 9414290', 'Cleveland 9063063']) {
      // Keyboard activation selects the exact accessible marker even where map pins overlap.
      const marker = page.getByRole('button', { name: station, exact: true });
      await marker.waitFor({ state: 'attached', timeout: 15000 });
      await marker.focus();
      const response = page.waitForResponse(r => r.url().endsWith('/show_graph') && r.request().method() === 'POST');
      await marker.press('Enter');
      expect((await response).status()).toBe(200);
      await expect(page.locator('#graph-partial .highcharts-title')).toContainText(station.replace(/ \d+$/, ''), { timeout: 30000 });
      const state = await chartState(page);
      expect(state.samples).toBeGreaterThan(10);
      expect(state.numeric).toBe(true);
      expect(state.series).toBe('Height');
      expect(state.unit).toBe('Height in feet');
      expect(state.subtitle).toBe('Source: NOAA CO-OPS API');
      await expect(page.locator('#map-container-small')).toBeVisible();
      results.push({ station, ...state });
    }
    await page.screenshot({ path: info.outputPath(`${name}-chart.png`), fullPage: true });
    await page.getByRole('button', { name: 'X', exact: true }).click();
    await expect(page.locator('#map-container-full')).toBeVisible();
    const remainingContainers = await page.locator('#tide-graph').count();
    await fs.writeFile(info.outputPath(`${name}.json`), JSON.stringify({ url, stations, results, remainingContainers, errors, failedRequests }, null, 2));
    // Soft assertions finish the diagnostic report even when the current production behavior has defects.
    expect.soft(results.every(r => r.graphContainers === 1), 'one graph after replacing station').toBe(true);
    expect.soft(remainingContainers, 'no leftover graph after close').toBe(0);
    expect(errors).toEqual([]);
  });
}

test('production and staging expose identical station inventory', async ({ page }, info) => {
  const production = await inventory(page, targets.production);
  const staging = await inventory(page, targets.staging);
  const prodIds = new Set(production.map(s => s.id));
  const stageIds = new Set(staging.map(s => s.id));
  const result = {
    productionCount: production.length, stagingCount: staging.length,
    onlyProduction: production.filter(s => !stageIds.has(s.id)),
    onlyStaging: staging.filter(s => !prodIds.has(s.id)),
    changed: production.filter(p => {
      const s = staging.find(s => s.id === p.id);
      return s && JSON.stringify(s) !== JSON.stringify(p);
    })
  };
  await fs.writeFile(info.outputPath('inventory-differences.json'), JSON.stringify(result, null, 2));
  expect.soft(result.onlyProduction.length, 'stations missing from staging; see inventory-differences.json').toBe(0);
  expect.soft(result.onlyStaging.length, 'additional staging stations; see inventory-differences.json').toBe(0);
  expect(result.changed.length, 'changed station metadata; see inventory-differences.json').toBe(0);
});

test('www production hostname has valid HTTPS and loads the app', async ({ page }) => {
  // Never ignore HTTPS errors: an expired certificate must fail this check.
  await page.goto('https://www.stranger-tides.com/', { timeout: 20000 });
  await expect(page.locator('#header')).toContainText('NOAA');
  await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible({ timeout: 30000 });
});
