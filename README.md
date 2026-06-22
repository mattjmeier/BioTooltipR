# BioTooltipR

`BioTooltipR` is a lightweight R helper package for adding browser-side [bio-tooltips](https://mattjmeier.github.io/bio-tooltips/) gene and chemical tooltips to R Markdown, Quarto, Shiny, pkgdown, and other HTML reports.

The R package does **not** reimplement the `bio-tooltips` JavaScript library in R. Instead, it:

1. emits ordinary HTML spans such as `<span class="gene-tooltip">TP53</span>`;
2. attaches the `bio-tooltips` JavaScript/CSS bundle through `htmltools`;
3. makes common R reporting patterns pleasant, especially inline prose and tables.

## Installation

Install the released version from CRAN:

```r
install.packages("BioTooltipR")

## Minimal R Markdown example

```r
library(BioTooltipR)

use_bio_tooltips()
```

Then use inline helpers in prose:

```r
The tumour suppressor `r gene_tt("TP53", species = "human")` responds to many forms of cellular stress.
```

Chemical tooltips can use visible-text lookup or stable identifiers:

```r
chem_tt("aspirin", query = "2244", scope = "pubchem")
chem_tt("caffeine", lookup = "best-guess")
```

## Tables

```r
library(BioTooltipR)

use_bio_tooltips(modules = "gene")

top_genes <- data.frame(
  symbol = c("TP53", "BRCA1", "GADD45A"),
  log2FoldChange = c(2.1, -1.4, 1.2),
  padj = c(0.0004, 0.002, 0.01)
)

top_genes |>
  gene_column(symbol, species = "human") |>
  bt_kable()
```

`bt_kable()` uses `escape = FALSE` by default so tooltip spans render as HTML.

## Explicit lower-level markup

```r
gene_tt("Trp53", species = "mouse")
chem_tt("benzo[a]pyrene", query = "2336", scope = "pubchem")
```

## Experimental auto-linking

For already-rendered prose, use a constrained vocabulary rather than scanning blindly:

```r
auto_gene_tooltips(
  genes = c("TP53", "BRCA1", "GADD45A"),
  species = "human",
  selector = ".results-section"
)
```

This feature is intentionally opt-in because many gene symbols are ordinary English words or ambiguous strings.

## Asset strategy

By default, `use_bio_tooltips()` uses vendored `bio-tooltips` 1.1.1,
D3 7.9.0, and Ideogram 1.53.0 browser assets included with this R package.
D3 and Ideogram are loaded only for the gene module. CDN assets remain
available when explicitly requested:

```r
use_bio_tooltips(cdn = TRUE, version = "1.1.1")
```
