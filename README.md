# Groundwater Drought Prediction using Ensemble Machine Learning

Code for an integrated framework that defines, detects, and predicts
groundwater drought across the Irish groundwater monitoring network, combining
the Standardised Groundwater Index (SGI) with ensemble machine learning. The
framework uses a two-phase, subset-based approach that distinguishes
quick-response from delayed-response groundwater systems.

> **Before publishing:** fill every `[bracketed]` placeholder, confirm the
> script filenames match the run order below, and delete this note.

---

## Citation

If you use this code, please cite:

> [Author(s)] ([Year]). [Manuscript title]. *[Journal]*, [vol(issue), pages].
> https://doi.org/[article DOI]

Archived code release: https://doi.org/[Zenodo or Figshare DOI]

---

## Repository structure

```
.
├── README.md
├── LICENSE
├── .gitignore
├── R/
│   ├── 00_download_data.R        # retrieve groundwater levels (KiWIS API) + raw inputs
│   ├── 01_feature_engineering.R  # SGI, lagged/antecedent features, 500 m hydrogeological extraction
│   ├── 02_sgi_monthly.R          # SGI monthly drought analysis
│   ├── 03_modelling_pipeline.R   # two-phase subset-based modelling (helper functions included)
│   └── helper_functions.R        # (only if you keep functions separate; otherwise inlined in 03)
├── data/
│   └── README.md                 # raw-source links + how to regenerate / request processed data
├── docs/
│   └── data_dictionary.md        # variable definitions and units
└── outputs/                      # generated figures/tables (git-ignored)
```

> **Filename note:** scripts should be numbered in run order. The modelling
> script is currently named `01_modelling_pipeline.R` but runs *last* — rename
> it to `03_modelling_pipeline.R`, and confirm SGI vs. feature-engineering order
> matches how you actually run them.

---

## Data availability

In line with the manuscript's Data Availability statement:

- **Analysis code and figure-generation scripts** — in this repository.
- **Raw input data** — publicly available from the original providers (EPA
  Ireland, Geological Survey Ireland, Copernicus GLO-30 DEM via OpenTopography,
  and [meteorological provider — confirm]). See [`data/README.md`](data/README.md)
  for links and access details.
- **Processed/derived datasets** — available from the corresponding author on
  reasonable request, or regenerable from the raw sources using the scripts here.

Raw and processed data are not committed to this repository (third-party
licensing and file size). Everything needed to reproduce the processed data
from the public sources is in `R/`.

---

## Requirements

- **R** version [X.X.X] (`R.version.string`)
- Install packages:

```r
install.packages(c(
  "tidyverse", "lubridate", "patchwork",
  "caret", "randomForest", "xgboost", "ebmc",
  "pROC", "ROCR", "MLmetrics"
  # add any others your final scripts load
))
```

> For an exact, reproducible environment, commit an `renv.lock`
> (https://rstudio.github.io/renv/). Recommended, given the reproducibility
> requirement.

---

## How to run

Run the scripts in `R/` in numerical order, from the repository root:

1. `00_download_data.R` — assemble raw inputs (requires access to the sources in `data/README.md`).
2. `01_feature_engineering.R` — build SGI and the predictor set.
3. `02_sgi_monthly.R` — SGI drought analysis and figures.
4. `03_modelling_pipeline.R` — train and evaluate the two-phase subset models.

### Method summary

- **Phase 1 — site-level:** one classifier per monitoring station, trained on
  meteorological inputs + SGI to predict monthly drought / non-drought.
- **Subset assignment:** sites are stratified into quick- vs delayed-response
  groups [state the rule].
- **Phase 2 — subset-level:** per-subset models trained on combined
  meteorological + hydrogeological features. RUSBoost gave the best
  minority-class performance.

Drought is defined as SGI ≤ −1.5 (see `docs/data_dictionary.md`).

---

## License

Released under the [MIT] License — see [LICENSE](LICENSE). Confirm the licence
choice; if you later add data, data and code are typically licensed separately
(e.g. CC-BY-4.0 for data).

---

## Contact

[Name] — [affiliation] — [email / ORCID]
