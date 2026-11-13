# Dependency upgrade and Heroku rollout

Work is on `codex/dependency-modernization`. Never merge this branch merely to test staging: both apps currently auto-deploy `main`.

## Deployment inventory (read-only inspection, 2026-11-12)

| Setting | Production | Staging |
| --- | --- | --- |
| App | `stranger-tides` | `stranger-tides-staging` |
| Current release | v264, rollback to v262 | v127 |
| Current source | `126c3aa9`, Rails 7.0.8.7 | `2d65325e`, Rails 7.1.5.1 |
| Runtime stack | heroku-22 | heroku-24 |
| Next build stack | heroku-26 | heroku-24 |
| Web dyno | Basic, running | Eco, scaled to zero |
| Maintenance | off | on |
| Database | PostgreSQL 15.18, essential-0 | none |

The production database has `metadata` as JSON, an integer primary key, and only the primary-key station index. Its migration history ends at `20151227112425`. The repo schema uses JSONB and includes the later station indexes. **Do not run `db:migrate`, `db:prepare`, `db:schema:load`, or station deletion/reseeding tasks against production as part of this dependency upgrade.** Several existing migrations have never run there. A future migration rollout must be reviewed separately and backed up first.

The old `rake deploy:production` task is disabled: it used a stale `master` ref and invoked data deletion/repopulation commands. There is no automatic release-phase migration in `Procfile`.

## Upgrade results

Ruby **4.0.9**, Rails **8.1.4.1**, Bundler **4.0.24**, Puma **8.0.2**, Rack **3.2.8**, PostgreSQL adapter **1.7.0**, Gon **8.0.0**, and RSpec Rails **8.1.0** are locked. The active Highcharts scripts were upgraded from **10.3.3** to **13.1.1** using the official npm package and its integrity hash.

The upgrade was tested through Rails 7.2, 8.0, and 8.1 checkpoints. All 38 current specs pass with Ruby 4.0.9 against both the repo schema and an isolated database matching production's integer primary key, JSON metadata column, and absent station indexes. Local PostgreSQL is 14.17; production is 15.18, and GitHub Actions tests PostgreSQL 15 and 18, and CircleCI uses PostgreSQL 15. The new GitHub workflow pins action revisions, has read-only repository permissions, and does not deploy. RuboCop reports zero offenses, Brakeman 8.1.0 reports zero security warnings, and bundler-audit reports no known vulnerabilities against advisory database commit `4d71b123428e33f694e805ce15351ee3d8d62ef7` (2026-11-11). Eager loading and production asset compilation pass. `bundle outdated --strict` reports the bundle is up to date.

A real NOAA request for San Francisco returns a chart. A production-mode local browser test renders that live chart with Highcharts 13.1.1 and verifies its close button. The Google Maps key correctly rejects localhost with `RefererNotAllowedMapError`; no key restrictions were relaxed. Full map/marker verification still requires the staging domain.

SassC was removed by compiling the existing stylesheet to equivalent plain CSS. jQuery 3 and explicit JavaScript graph responses replace the old jQuery 1 path. The map marker URL now comes from Rails' fingerprinted asset helper in the HTML rather than the removed `js_assets` global helper. Framework defaults remain at 7.0 to limit behavioral changes; the cache format is set to 7.1 because Rails 8 removes the older format. This app does not use image variants, so their processor is disabled rather than adding an unused image library.

The application has no Sidekiq workers or worker dyno. Sidekiq's obsolete Rack constraint was removed; Redis remains explicitly available for Action Cable. Turbolinks, LazyHighCharts, and Sprockets are retained to preserve the existing UI; their latest compatible releases are locked. Historical, inactive Highcharts modules are not loaded by the asset manifest.

Staging database provisioning was approved at $5/month, but Heroku rejected it because the authenticated `jfernandez700@gmail.com` account is a collaborator. Only the owner `josefernandez@joseworks.org` can provision the paid add-on. Production configuration, dynos, releases, data, and automatic deployment settings have not been changed.

## Local validation

Use the Ruby version in `.ruby-version`, run `bundle install`, and supply a local-only PostgreSQL URL. Never copy Heroku production config into `.env` for tests or `heroku local`.

```sh
export DATABASE_URL=postgresql://localhost/stranger_tides_upgrade_test
RAILS_ENV=test bundle exec rails db:create db:schema:load
bundle exec rspec
bundle exec rails zeitwerk:check
bundle exec bundler-audit check --update
bundle exec brakeman --no-pager
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile
```

RSpec uses fixed NOAA HTTP responses and blocks external HTTP. This proves application behavior without depending on NOAA availability; separately smoke-test real tide data on staging. Schema loading is for the disposable local database only.

No checks were reported for the initial draft head by the old CircleCI integration, so GitHub Actions was added to provide visible test and security checks on this PR. Hosted results must be checked separately from local results.

## Staging rollout

1. Provision a **separate** database for `stranger-tides-staging` after approving its cost. Never attach production's database. Verify the database hosts differ, and use staging-specific secrets and Google Maps referrer restrictions. Leave production auto-deploy settings untouched while working on the upgrade branch.
2. Deploy the committed upgrade branch directly to the staging Heroku Git remote (its `master` ref is an ancestor and accepts a fast-forward; its old `main` ref has divergent historical commits and must not be overwritten), with `--app stranger-tides-staging` on every Heroku command. Initialize only the new, empty staging database from the repo schema and populate staging station data. No production data copy is required.
3. Scale staging's web dyno to one, disable maintenance on staging, and inspect logs. Verify the home page, station markers, marker icons, a live NOAA tide graph, graph close behavior, and fingerprinted CSS/JavaScript assets. Use browser refresh after the asset change. Measure an actual NOAA request separately from the offline test suite.
4. Record staging's exact commit, release, stack, Ruby/Rails versions, and test results. Review all CI results and fetch the latest PR review summaries, unresolved inline threads, and security findings for that exact head. Address confirmed findings and document dismissals with evidence. Pending requested security reviews block merge.
5. Only after explicit production rollout approval: disable production's automatic `main` deployment, capture a production backup, record the current release/slug/config, reconcile the next-build stack discrepancy, and rehearse rollback. Promote the tested staging slug only after compatibility and reviews pass. Recheck the exact head's reviews immediately before merging. Do not run production migrations during this dependency-only promotion.

## Rollback

Before changing production, verify `heroku releases:info v264 --app stranger-tides` and confirm the previous slug remains available. Keep the known-good slug and configuration recorded. `heroku releases:rollback v264 --app stranger-tides` changes production and must only be used when an approved rollout needs recovery. A release rollback does **not** undo database migrations, configuration changes, or add-on upgrades. This upgrade therefore avoids all of those production mutations.

## Sources

- [Heroku Ruby support](https://devcenter.heroku.com/articles/ruby-support-reference)
- [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Ruby downloads](https://www.ruby-lang.org/en/downloads/)
