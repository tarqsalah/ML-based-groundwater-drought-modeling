# Data Dictionary

Variable definitions for the modelling feature set used in this study. This
serves as the metadata reference for the deposited code and for the processed
data available on request.

---

## Identifiers and target

| Variable | Description | Type / Units |
|---|---|---|
| `station_code` / `code` | Unique groundwater monitoring station identifier | categorical |
| `station_name` | Station name | categorical |
| `date` | Observation month (or week) | date |
| `SGI` | Standardised Groundwater Index (normal-score transform of ranked groundwater level, computed per calendar month) | dimensionless (z-score) |
| `event` | SGI severity class: Extreme (SGI ≤ −2.0), Severe (−2.0 < SGI ≤ −1.5), Moderate, Mild, Normal | categorical (ordered) |
| `drought` / `actual` | Binary target: 1 = drought (SGI ≤ −1.5), 0 = non-drought | binary (0/1) |

---

## Meteorological predictors

| Variable | Description | Units |
|---|---|---|
| `lag.rain.1 … lag.rain.6` | Precipitation lagged 1–6 months (monthly series) | [mm] |
| `lag.rain.wk1 … lag.rain.wk4` | Precipitation lagged 1–4 weeks (weekly series) | [mm] |
| `cum.rain1 … cum.rain6` | Antecedent cumulative precipitation over the preceding 1–6 months | [mm] |
| `cum.rain.wk1 … cum.rain.wk4` | Antecedent cumulative precipitation over the preceding 1–4 weeks | [mm] |
| `train / train.wk1 …` | Antecedent mean temperature over the preceding period (1–4 weeks weekly; up to 6 months monthly) | [°C] |

---

## Groundwater-state predictors

| Variable | Description | Units |
|---|---|---|
| `SGI.1`, `SGI.2` | SGI lagged 1 and 2 months | dimensionless |
| `gw.memory` / response time | Estimated groundwater response time (lag at which groundwater level correlates most strongly with the climate signal) | [days] |

---

## Hydrogeological predictors (extracted within a 500 m buffer per site)

| Variable | Description | Type / Units |
|---|---|---|
| `elevation` | Mean ground elevation | [m] |
| `slope` | Mean slope | [degrees or %] |
| `HAND` | Height Above Nearest Drainage (mean) | [m] |
| `land.cover` | Dominant land-cover class | categorical |
| `subsoil.permeability` | Dominant subsoil permeability class | categorical (high/moderate/low) |
| `drainage` | Dominant soil drainage class | categorical |
| `aquifer.category` | Dominant aquifer category (e.g. Rkc, Rg, Pl, Ll) | categorical |
| `aquifer.importance` | Aquifer importance class (Regional / Local / Poor) | categorical |
| `gw.vulnerability` | Dominant groundwater vulnerability class | categorical |

> Continuous layers were summarised by their mean within the 500 m buffer;
> categorical layers by their dominant (majority-area) class.

---

## Provenance

- Raw sources and access dates: see `../data/README.md`.
- Coordinate reference system: Irish Transverse Mercator (ITM).
