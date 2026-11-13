const { test, expect } = require('@playwright/test');
const path = require('node:path');

test.beforeEach(async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('https://maps.googleapis.com/**', route => route.fulfill({
    path: path.join(__dirname, 'maps-fixture.js'), contentType: 'application/javascript'
  }));
  page.testErrors = errors;
});
test.afterEach(async ({ page }) => expect(page.testErrors).toEqual([]));

test('map survives denied location and serves real fingerprinted marker images', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible();
  for (const name of ['San Francisco 9414290', 'Duluth 9099064']) {
    const marker = page.getByRole('button', { name, exact: true });
    await expect(marker).toBeVisible();
    await expect(marker.locator('img')).toHaveJSProperty('naturalWidth', 32);
    await expect(marker.locator('img')).toHaveAttribute('src', /orange_marker.*\.png/);
  }
});

test('marker click renders real chart data, close restores map, another station opens', async ({ page }) => {
  await page.goto('/');
  for (const station of ['San Francisco', 'Duluth']) {
    const id = station === 'Duluth' ? '9099064' : '9414290';
    const response = page.waitForResponse(r => r.url().endsWith('/show_graph') && r.request().method() === 'POST');
    await page.getByRole('button', { name: `${station} ${id}`, exact: true }).click();
    expect((await response).status()).toBe(200);
    await expect(page.locator('#graph-partial .highcharts-title')).toContainText(`Station name: ${station}`);
    await expect(page.locator('#map-container-small')).toBeVisible();
    expect(await page.evaluate(() => window.chart_graph_partial.series[0].yData ?? window.chart_graph_partial.series[0].getColumn('y'))).toEqual([0.12, 0.15, 0.18]);
    await page.getByRole('button', { name: 'X', exact: true }).click();
    await expect(page.locator('#tide-graph')).toHaveCount(0);
    await expect(page.locator('#map-container-full')).toBeVisible();
  }
});

test('selecting another marker while chart is open leaves one current chart', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'San Francisco 9414290', exact: true }).click();
  await expect(page.locator('#graph-partial .highcharts-title')).toContainText('San Francisco');
  await page.getByRole('button', { name: 'Duluth 9099064', exact: true }).click();
  await expect(page.locator('#graph-partial .highcharts-title')).toContainText('Duluth');
  await expect(page.locator('#tide-graph')).toHaveCount(1);
  await expect(page.locator('#graph-partial')).toHaveCount(1);
  await page.getByRole('button', { name: 'X', exact: true }).click();
  await expect(page.locator('#tide-graph')).toHaveCount(0);
});

test('location control recenters the map after location is granted', async ({ context, page }) => {
  await context.grantPermissions(['geolocation']);
  await context.setGeolocation({ latitude: 37.8, longitude: -122.4 });
  await page.goto('/');
  await page.getByText('Center Map on your location', { exact: true }).click();
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom', '9');
  await expect(page.locator('#full_map')).toHaveAttribute('data-center', '{"lat":37.8,"lng":-122.4}');
});
