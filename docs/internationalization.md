# Application languages

Independent feature branch `codex/internationalization`, based on main. English is the default; Spanish, French and German are selectable in the header by their own names. No browser-language guessing, translation service, API key or subscription. Production and the UK-only staging preview are unchanged by this branch.

## Behavior

Use `?locale=en`, `es`, `fr` or `de`. An explicit supported choice is remembered in a host-only, HttpOnly, SameSite=Lax cookie (Secure on HTTPS); the URL takes precedence over the cookie, with English fallback. Language changes preserve station IDs, units, time-zone choice, selected tab and historical dates already encoded in the URL. They perform a deliberate page navigation; measurement/time selectors keep their existing in-place behavior.

Rails scopes the locale to each request with `I18n.with_locale`, sets HTML `lang` and Content-Language, and varies responses by Cookie. It never sets a process-wide user locale. Language values are allowlisted before setting cookies or choosing translations.

The four `config/locales/ui.*.yml` dictionaries use literal English source phrases as keys under `messages`, shared by ERB (`ui`) and JavaScript (`AppI18n.t`). Periods inside phrases are not treated as nested keys. Tagged templates use numbered interpolation slots so translations may reorder values. Dictionary content enters the page as escaped application/json and is parsed as data; user/source values are rendered through textContent, not HTML. Unknown upstream diagnostic messages fall back to their original wording.

The interface, controls, warnings, product labels, charts, tables, photo captions and accessibility labels are translated. Dates use the selected language independently of the selected time zone; numbers use locale-aware decimal/group separators. Highcharts month/day labels and common controls are localized, and Google Maps receives the chosen language. Native browser location prompts remain controlled by the browser/OS.

Station/place names, NOAA official organizational names, source identifiers, datums, unit symbols, raw source descriptions and machine-readable CSV field names/product codes stay unchanged. CSV numeric values retain machine-readable decimal points; screen formatting never changes scientific values or datum references. No automatic translation of station names or model output is attempted.

## Maintaining translations

Add a phrase to all four dictionaries and preserve every `{n}` interpolation slot. Use `tr('Phrase')` or tagged templates in JavaScript and `ui('Phrase')` in ERB. Keep translations out of provider URLs, product identifiers, CSS selectors and request parameters. Request tests compare dictionary keys/interpolation slots; browser scenarios cover all four languages, source identity, charts, history/CSV, remembered selection and narrow layouts. Native-speaker review can refine terminology without changing the translation infrastructure.

This branch is independent from UK and Canadian work. When combining it with the UK branch, add translations for the UK-specific network controls, source explanations and attribution, preserving the fixed Environment Agency acknowledgement and proper organization names. Resolve the small shared view/controller edits explicitly, then rerun both feature suites. Do not silently treat three separate branches as a combined staging deployment.
