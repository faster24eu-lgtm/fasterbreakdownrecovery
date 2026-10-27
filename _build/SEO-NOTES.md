# SEO notes – fasterbreakdownrecovery.co.uk

Playbook for all Faster sites: `takeldienstfaster/SEO-STRATEGY-NO-BACKLINKS.md` (ranking without backlinks: Search Console queries → content and internal anchors).
This file lives in `_build/`, so GitHub Pages does not publish it.

## 2026-10-18 – internal links and clean hub URLs (no text changes)
Search Console (`https://fasterbreakdownrecovery.co.uk/`, data since 2026-10-12): 15 pages with impressions, 48 impressions, 0 clicks. Too little data for the query-driven part of the playbook (working queries into content, varying anchors, titles). Repeat that part once there are a few weeks of data. The `sc-domain:` property is not accessible to the connected Google account (403).
Baseline: / 7 impr. pos 29; /areas/leicester.html 7 / 65; /areas/cardiff.html 5 / 6; /fr/ 4 / 5.5; /routes/m6.html 4 / 24; /areas/ 3 / 4.7; /areas/glasgow.html 3 / 29; /areas/london.html 3 / 86; /routes/m25.html 3 / 28.

Changes in `build.pl`, page loop:
- About 2,600 links to `…/index.html` (home, hubs, language homes) now point to the folder URL, which matches the canonical and sitemap. Search Console had already reported `/nl/index.html` as its own page.
- `link_mentions()`: on English pages, the first unlinked mention of a city or road name in a `<p>`/`<li>` becomes a link to that page (about 55 new contextual links). Max 3 per page; least-linked targets first; skips targets already linked in the body (the Nearby block does not count); skips list items that are already links; skips names followed by Road/Street/…; no road links on Northern Ireland pages (their M1/M2 are not ours). The build dies if the visible text changes.
- Before: Belfast, Bradford, Hull, Newcastle, Plymouth, Southampton, M11, M20, M23, M40, M60 and M74 each had 1 in-body link from another page. After: 2–3, except Plymouth and Southampton (hardly mentioned anywhere).

## 2026-10-27 – Cut to the pages Google shows (127 → 75 sitemap URLs)
Same move as abschleppdienst-faster.de on 2026-10-25 (that site went from position ~33 to ~22 within two days). Search Console (`https://fasterbreakdownrecovery.co.uk/`, 27 Sep–27 Oct): 39 of 127 sitemap URLs had impressions; the site peaked at ~100 impressions/day around 22 Oct and fell back to ~50 by 25–26 Oct.
- Removed 52 pages with 0 impressions (list in `_build/removed-pages.txt`): 11 area pages (Aberdeenshire towns, Belfast, Bradford, Hull, Plymouth, Southampton), the 8 `services/*-aberdeen` pages, the 16 repatriation country/city pages, and fr/nl/pl/ro subpages without impressions.
- Kept: every page with impressions, all West Midlands area pages (Birmingham is the focus), all routes and guides, core services, hubs, legal.
- Old URLs: `services/*-aberdeen` → the general service page, language subpages → their language home, repatriation pages → `/repatriation/` (noindex meta-refresh stubs, `write_redirects`). Removed area pages 404.
- `drop_gone_links()` in build.pl: links to removed pages follow the redirect if there is one, otherwise list items are dropped and in-text links become plain text; empty lists / headings / Related sections left behind are removed. 0 broken links.
- Sitemap lastmod kept from the previous sitemap, 2026-10-27 for the 26 changed pages. Re-check positions/clicks from ~2026-11-15.
