# Physical phone and tablet acceptance

Run this checklist on **real hardware**, against the exact staging release being considered for production. Keep the full automated suite: the current baseline is 66 scenarios / 264 CI checks (the earlier baseline was 212). Browser emulation, desktop Brave and desktop WebKit do not establish native Android or iOS permission/fullscreen behavior.

## Record the run

| Field | Record |
| --- | --- |
| Date, tester, staging release and commit | Pending physical verification |
| Android phone + tablet model, Android version, Brave version | Pending |
| iPhone + iPad model, iOS/iPadOS version, Safari version | Pending |
| Site, orientation, browser zoom / display scaling | `https://stranger-tides-staging.herokuapp.com/`, portrait + landscape |
| Result / evidence / issue link | Not run; do not label an emulated run as a physical pass |

## Five acceptance checks (about 8 minutes per device)

1. **Permission identity (2 minutes).** In a fresh private tab, type the staging HTTPS address directly. Before tapping location, no prompt should appear. Confirm the page's “Location request from” host matches the address bar. Tap the small map target icon; the browser/OS permission prompt must identify this site (or its normal browser-level OS permission), never an unrelated domain. Record the exact label and browser version. If wrong, cancel and record it; page metadata cannot set the browser-controlled origin label. Do not grant the unrelated site permission.
2. **Consent and recovery (2 minutes).** Deny once: map/list and both location controls remain usable with readable feedback. Reset this site's permission using the browser UI, retry and allow if comfortable. Both location buttons center the map without scrolling; no duplicate pending prompt appears. Keep screenshots free of precise coordinates and personal browser tabs. The tester decides whether to grant location.
3. **Fullscreen and rotation (1 minute).** Enter/exit map fullscreen where offered, in both orientations. The target icon and overlap close/search/page controls stay visible and tappable; exiting restores normal layout. On devices/browsers without map fullscreen, record “not supported” and verify the normal-map controls rather than pretending fullscreen passed.
4. **Overlapping pins (2 minutes).** At a wide zoom around San Francisco, tap overlapping stations. Named radial choices appear without repeated zooming. Search for Alameda, select it, and confirm the report station/ID; map center and zoom stay unchanged. Repeat in landscape and fullscreen where supported. Check a dense group for paging, legible touch targets and reachable Close.
5. **Historical dates and download (1 minute).** Open a station, expand historical dates, load `2020-01-01` through `2020-03-31` with Automatic. Confirm hourly labels; export CSV and open it from the device's Downloads/Files UI. Confirm station, UTC timestamps, datum, units and range headers. Change to monthly and confirm calendar-month labels. The page remains usable after download.

## Acceptance record

| Device / browser | Identity + consent | Fullscreen / rotation | Radial selection | Historical CSV | Evidence |
| --- | --- | --- | --- | --- | --- |
| Android phone / Brave | Not run | Not run | Not run | Not run | — |
| Android tablet / Brave | Not run | Not run | Not run | Not run | — |
| iPhone / Safari | Not run | Not run | Not run | Not run | — |
| iPad / Safari | Not run | Not run | Not run | Not run | — |

Record failures with model/OS/browser, exact steps and staging release. Re-test the affected check after a fix. Native-device acceptance remains pending until a person with the physical device records the result; green CI does not fill this table.
