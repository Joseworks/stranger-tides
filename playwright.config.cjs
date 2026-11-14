const { defineConfig, devices } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './tests/browser', testMatch: 'regression.spec.cjs',
  outputDir: 'test-results/regression',
  fullyParallel: false, workers: 1, retries: 0,
  reporter: [['list'], ['html', { outputFolder: 'playwright-report/regression', open: 'never' }]],
  use: { baseURL: 'http://127.0.0.1:3467', trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: [
    { name: 'desktop-chromium', use: { ...devices['Desktop Chrome'], channel: process.env.PLAYWRIGHT_CHANNEL } },
    { name: 'mobile-chromium', use: { ...devices['Pixel 5'], channel: process.env.PLAYWRIGHT_CHANNEL } },
    { name: 'mobile-webkit', use: { ...devices['iPhone 13'] } }
  ],
  webServer: {
    command: 'bundle exec ruby tests/browser/server.rb',
    url: 'http://127.0.0.1:3467', reuseExistingServer: false, timeout: 60000,
    env: { RAILS_ENV: 'test' }
  }
});
