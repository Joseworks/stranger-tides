# NOAA products release security assessment

Puma 8.0.2 is affected by seven advisories published November 13, 2026. Upgrade to 8.1.0 fixes all seven (patched 8.x threshold: 8.0.3). Public advisory database refreshed November 15; bundler-audit reports no vulnerabilities. Heroku routing may reduce exposure, but is not used as a reason to dismiss any finding.

| Finding | Severity | Impact / exposure assessment | Disposition |
|---|---|---|---|
| [GHSA-86xc-wrr9-xmmq](https://github.com/puma/puma/security/advisories/GHSA-86xc-wrr9-xmmq) | High | TLS control-server identity is not verified; a network intermediary could steal the control token. No SSL control app is configured here. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-jm4r-w4xx-qxw7](https://github.com/puma/puma/security/advisories/GHSA-jm4r-w4xx-qxw7) | Moderate | Trickled bodies can prevent single-mode shutdown and delay recovery. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-m5xw-3hrw-qcmf](https://github.com/puma/puma/security/advisories/GHSA-m5xw-3hrw-qcmf) | Moderate | Slow clients can keep expired connections open and consume resources. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-r885-m39c-939g](https://github.com/puma/puma/security/advisories/GHSA-r885-m39c-939g) | Moderate | Certain TLS cipher filters allow a wider list. No Puma TLS listener or cipher filter is configured here. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-rf6g-xhmp-gm7v](https://github.com/puma/puma/security/advisories/GHSA-rf6g-xhmp-gm7v) | High | Descriptor exhaustion can cause log flooding and service unavailability. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-x646-wp7c-h9mg](https://github.com/puma/puma/security/advisories/GHSA-x646-wp7c-h9mg) | High | Slow readers of TLS/file responses can exhaust worker threads; file responses may apply even without Puma TLS. | Fixed by Puma 8.1.0; startup and full regressions required. |
| [GHSA-xw3h-pgr9-3vg7](https://github.com/puma/puma/security/advisories/GHSA-xw3h-pgr9-3vg7) | High | Blocked interim/error response writes can stall the reactor and other clients. | Fixed by Puma 8.1.0; startup and full regressions required. |

Copilot also reported a medium-severity unbounded-buffer issue in the new NDBC client. The client now streams and rejects chunks before the cumulative buffer exceeds 2 MiB; an early-abort regression verifies further chunks are not consumed. Other review findings concern chart cadence, stale optional data, pagination, disclosure state, keyboard focus, and malformed optional dates; fixes and regressions are included.

Historical Google secret alerts remain assessed separately: one expired; one restricted to Maps JavaScript API and the previously approved HTTPS Heroku origins. Keys are not reproduced here. No database migration, catalog update, new permissions or production scheduler is part of this release.
