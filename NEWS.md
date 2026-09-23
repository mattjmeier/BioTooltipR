# BioTooltipR 0.1.2

- Updated the vendored `bio-tooltips` runtime to 2.3.1, bringing the latest
  accessibility and mobile interaction improvements to generated reports.

- `bt_plotly_gene_hover()` now uses the `bio-tooltips` 2.1.0 programmatic
  `GeneTooltip.attach()` adapter instead of reinitializing the global gene
  module per hover. One attached anchor is reused as the selected point
  changes, and repeated widget renders no longer accumulate listeners.
- On touch devices, tapping a plot point opens the gene tooltip as a
  persistent bottom drawer (on screens at or below 600 CSS pixels wide).
  Desktop hover behavior is unchanged, and the desktop tooltip card can now be
  moused into without closing.

# BioTooltipR 0.1.1

- Update dependencies and vendor code
- Update tooltips with the `bio-tooltips` v2.0.X Floating UI engine.

# BioTooltipR 0.1.0

- Finalized package code
- Added examples to vignette including `plotly` tooltips

# BioTooltipR 0.0.0.9000

## Added

- Initial draft package skeleton.
- `use_bio_tooltips()` for attaching the `bio-tooltips` JavaScript/CSS bundle to HTML reports.
- `gene_tt()` and `chem_tt()` helpers for inline R Markdown prose.
- `gene_column()`, `chem_column()`, and `tooltip_column()` helpers for data frames.
- `bt_kable()`, `bt_datatable()`, and `bt_deg_table()` report/table conveniences.
- Experimental `auto_gene_tooltips()` for vocabulary-limited post-render text wrapping.
