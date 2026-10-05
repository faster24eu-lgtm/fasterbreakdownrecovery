# Building fasterbreakdownrecovery.co.uk

Every page is generated. **Edit the sources in `_build/pages/`, never the `.html` files in the site root.**

```
perl _build/build.pl
```

writes every page plus `sitemap.xml`, and reports broken internal links (should be 0).

- `_build/pages/<path>.page` → `<path>.html`
- Header, menus, breadcrumbs, footer, phone/WhatsApp and the sitemap come from `build.pl` (edit `@NAV`, `@FOOTER_*`, `$PHONE*` there).
- New city / motorway / guide pages: copy an existing `template: standard` page (e.g. `areas/leeds.page`, `routes/m62.page`) and change the fields, BODY and FAQ. Set `kind` and `region` so it shows up on the hub pages automatically.
- `import.pl` was a one-time import of the original hand-written pages; don't run it again.

GitHub Pages ignores folders starting with `_`, so `_build/` is not published.
