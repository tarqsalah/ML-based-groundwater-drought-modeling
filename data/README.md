# Data

This folder is intentionally left without data files. The raw inputs are
third-party datasets available from their original providers, and the processed
datasets derived from them are available from the corresponding author on
reasonable request (see the Data Availability statement in the manuscript).

Everything needed to regenerate the processed data from the public sources is
in the analysis code (`../R/`), so the study is fully reproducible from the
sources listed below.

---

## Raw data sources (publicly available)

> Verify each link and access date before publishing; update any that have moved.

| Dataset | Provider | Access |
|---|---|---|
| Groundwater level records | EPA Ireland — HydroNet | https://epawebapp.epa.ie/hydronet/
| Precipitation & temperature | Met Éireann | https://www.met.ie/climate/available-data/daily-data) |
| Aquifer category, subsoil permeability, groundwater vulnerability, HAND | Geological Survey Ireland (GSI) | https://www.gsi.ie/en-ie/data-and-maps/Pages/default.aspx
| Soil hydrology | EPA Ireland — geoportal | https://gis.epa.ie/geonetwork/srv/eng/catalog.search#/metadata/c67bfab5-733f-4e6a-b60e-3cf037b5729a)|
| Topography (elevation, slope) | Copernicus GLO-30 DEM, via OpenTopography (ESA, 2024) | https://portal.opentopography.org/ |

Notes:
- Access dates: data were retrieved [month/year] — state the retrieval window,
  since some of these services update continuously.
- The raw layers are not re-hosted here because of their size and their
  providers' licensing terms; please obtain them directly from the sources above.

---

## Regenerating the processed data

Run the scripts in `../R/` in order:

```
00_download_data.R        # retrieve groundwater levels (KiWIS API) + assemble raw inputs
01_feature_engineering.R  # SGI, lagged/antecedent features, 500 m hydrogeological extraction
02_sgi_monthly.R          # SGI drought analysis
03_modelling_pipeline.R   # two-phase subset-based modelling
```

This reproduces the processed feature sets used for modelling. See
`../docs/data_dictionary.md` for variable definitions and units.

---

## Processed data on request

The processed/derived datasets (the modelling feature tables) are available from
the corresponding author on reasonable request. Contact: [name, email/ORCID].
