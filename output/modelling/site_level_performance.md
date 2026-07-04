# Site-level model performance (Phase 1)

Per-station cross-validated performance of the site-level drought classifier.
Stations are stratified into response subsets using an AUC-ROC threshold of
**0.80**: AUC-ROC >= 0.80 -> Subset-1 (quick-response); AUC-ROC < 0.80 ->
Subset-2 (delayed-response).

Split: **Subset-1 = 32 stations**, **Subset-2 = 68 stations** (100 total).

| Station Code | Station Name | AUC-ROC | AUC-PR | Subset |
|---|---|---|---|---|
| GW_1 | AGHADRESTAN | 0.83 | 0.75 | Subset-1 |
| GW_2 | ALLEN | 0.60 | 0.60 | Subset-2 |
| GW_3 | ATHENRY | 0.82 | 0.68 | Subset-1 |
| GW_4 | BALLINROBE GWL | 0.72 | 0.63 | Subset-2 |
| GW_5 | BALLYCASTLE GWL | 0.65 | 0.57 | Subset-2 |
| GW_6 | BALLYRAGGET GLANBIA | 0.96 | 0.90 | Subset-1 |
| GW_7 | BALLYSAX | 0.53 | 0.61 | Subset-2 |
| GW_8 | BAWN BOY WORKHOUSE | 0.71 | 0.67 | Subset-2 |
| GW_9 | BEGGARS BUSH | 0.53 | 0.58 | Subset-2 |
| GW_10 | BOG OF THE RING HR2D | 0.50 | 0.57 | Subset-2 |
| GW_11 | BOG OF THE RING OW2S | 0.41 | 0.55 | Subset-2 |
| GW_12 | BOG OF THE RING OW3D | 0.65 | 0.59 | Subset-2 |
| GW_13 | BOG OF THE RING OW3S | 0.63 | 0.62 | Subset-2 |
| GW_14 | BROWNSTOWN | 0.53 | 0.61 | Subset-2 |
| GW_15 | CLBH5 DEEP | 0.64 | 0.58 | Subset-2 |
| GW_16 | CLINTYGRIGNEY MORTONS | 0.53 | 0.58 | Subset-2 |
| GW_17 | CLOONAMAGAUNNA | 0.64 | 0.59 | Subset-2 |
| GW_18 | CORBALLY | 0.80 | 0.68 | Subset-1 |
| GW_19 | DR1 DEEP UPPER SITE | 0.66 | 0.60 | Subset-2 |
| GW_20 | DR1 SHALLOW UPPER SITE | 0.67 | 0.65 | Subset-2 |
| GW_21 | DR1 SHALLOW2 UPPER SITE | 0.68 | 0.65 | Subset-2 |
| GW_22 | DR2 SHALLOW | 0.71 | 0.61 | Subset-2 |
| GW_23 | DR3 DEEP LOWER SITE | 0.61 | 0.60 | Subset-2 |
| GW_24 | DR3 SHALLOW LOWER SITE | 0.73 | 0.67 | Subset-2 |
| GW_25 | DR3 SUBSOIL LOWER SITE | 0.52 | 0.53 | Subset-2 |
| GW_26 | DR3 TRANSITION LOWER SITE | 0.59 | 0.57 | Subset-2 |
| GW_27 | DRUIDS GLEN GWL | 0.76 | 0.66 | Subset-2 |
| GW_28 | DUFFYS CROSSROADS | 0.81 | 0.64 | Subset-1 |
| GW_29 | DUNSHAUGHLIN PW6 | 0.72 | 0.65 | Subset-2 |
| GW_30 | FBH1 - FLESK | 0.76 | 0.66 | Subset-2 |
| GW_31 | FBH9 - FLESK | 0.80 | 0.63 | Subset-1 |
| GW_32 | FRESHFORD - JOHNSTOWN RD | 0.70 | 0.64 | Subset-2 |
| GW_33 | GC1 DEEP | 0.69 | 0.66 | Subset-2 |
| GW_34 | GC1 SHALLOW | 0.73 | 0.63 | Subset-2 |
| GW_35 | GC2 SHALLOW | 0.55 | 0.61 | Subset-2 |
| GW_36 | GC2 SUBSOILS | 0.69 | 0.68 | Subset-2 |
| GW_37 | GC2 TRANSITION | 0.66 | 0.64 | Subset-2 |
| GW_38 | GC3 DEEP | 0.79 | 0.71 | Subset-2 |
| GW_39 | GC3 SHALLOW | 0.75 | 0.63 | Subset-2 |
| GW_40 | GC3 SUBSOILS | 0.56 | 0.64 | Subset-2 |
| GW_41 | GC3 TRANSITION | 0.74 | 0.62 | Subset-2 |
| GW_42 | GO1 DEEP | 0.86 | 0.77 | Subset-1 |
| GW_43 | GO1 SHALLOW | 0.85 | 0.75 | Subset-1 |
| GW_44 | GO1 TRANSITION | 0.95 | 0.83 | Subset-1 |
| GW_45 | GO2 DEEP | 0.91 | 0.81 | Subset-1 |
| GW_46 | GO2 SHALLOW | 0.58 | 0.67 | Subset-2 |
| GW_47 | GO2 TRANSITION | 0.81 | 0.72 | Subset-1 |
| GW_48 | GO3 DEEP | 0.91 | 0.74 | Subset-1 |
| GW_49 | GO3 SHALLOW | 0.81 | 0.74 | Subset-1 |
| GW_50 | GO3 SUBSOIL | 0.97 | 0.91 | Subset-1 |
| GW_51 | GO3 TRANSITION | 0.76 | 0.70 | Subset-2 |
| GW_52 | HEIGHT FOR HIRE | 0.70 | 0.60 | Subset-2 |
| GW_53 | KILCOOLE GWL | 0.82 | 0.72 | Subset-1 |
| GW_54 | KILLALA | 0.80 | 0.72 | Subset-1 |
| GW_55 | KILLINY | 0.75 | 0.65 | Subset-2 |
| GW_56 | KILTROUGH TOWER | 0.50 | 0.58 | Subset-2 |
| GW_57 | KNOCKLAUN | 0.74 | 0.65 | Subset-2 |
| GW_58 | KNOCKTOPHER | 0.90 | 0.80 | Subset-1 |
| GW_59 | LACKAGH | 0.81 | 0.66 | Subset-1 |
| GW_60 | LANDFILL SITE | 0.67 | 0.60 | Subset-2 |
| GW_61 | LISATAVA | 0.87 | 0.73 | Subset-1 |
| GW_62 | MAGHERARNEY GWL | 0.86 | 0.75 | Subset-1 |
| GW_63 | MATTOCK MK1 DEEP | 0.61 | 0.58 | Subset-2 |
| GW_64 | MATTOCK MK1 SHALLOW | 0.63 | 0.62 | Subset-2 |
| GW_65 | MATTOCK MK2 DEEP | 0.51 | 0.53 | Subset-2 |
| GW_66 | MATTOCK MK3 DEEP | 0.66 | 0.59 | Subset-2 |
| GW_67 | MATTOCK MK3 SHALLOW | 0.64 | 0.63 | Subset-2 |
| GW_68 | MATTOCK MK3 SUBSOIL2 | 0.80 | 0.70 | Subset-1 |
| GW_69 | MAYO ABBEY | 0.71 | 0.59 | Subset-2 |
| GW_70 | MB 07A (MIDDLE) | 0.68 | 0.58 | Subset-2 |
| GW_71 | MB 29 | 0.68 | 0.65 | Subset-2 |
| GW_72 | MB 30 | 0.68 | 0.65 | Subset-2 |
| GW_73 | MUCHGRANGE FENCE | 0.77 | 0.64 | Subset-2 |
| GW_74 | NV1 DEEP | 0.43 | 0.52 | Subset-2 |
| GW_75 | NV1 SHALLOW 1 | 0.69 | 0.65 | Subset-2 |
| GW_76 | NV1 SHALLOW 2 | 0.67 | 0.60 | Subset-2 |
| GW_77 | NV1 TRANSITION | 0.89 | 0.75 | Subset-1 |
| GW_78 | NV2 DEEP | 0.85 | 0.76 | Subset-1 |
| GW_79 | NV2 SHALLOW | 0.70 | 0.58 | Subset-2 |
| GW_80 | NV2 TRANSITION | 0.70 | 0.64 | Subset-2 |
| GW_81 | NV3 DEEP | 0.63 | 0.59 | Subset-2 |
| GW_82 | NV3 SHALLOW | 0.73 | 0.68 | Subset-2 |
| GW_83 | NV3 TRANSITION | 0.85 | 0.77 | Subset-1 |
| GW_84 | OLD LUNG BRIDGE | 0.80 | 0.73 | Subset-1 |
| GW_85 | OLDTOWN | 0.67 | 0.67 | Subset-2 |
| GW_86 | PUB IN PIKE | 0.84 | 0.74 | Subset-1 |
| GW_87 | RATHDUFF | 0.85 | 0.80 | Subset-1 |
| GW_88 | ROSCOMMON GOLF CLUB | 0.85 | 0.76 | Subset-1 |
| GW_89 | RW1 - DEEP | 0.79 | 0.64 | Subset-2 |
| GW_90 | RW1 - SHALLOW | 0.85 | 0.74 | Subset-1 |
| GW_91 | RW1 - TRANSITION | 0.86 | 0.78 | Subset-1 |
| GW_92 | RW2 - SHALLOW | 0.78 | 0.74 | Subset-2 |
| GW_93 | RW2 - TRANSITION | 0.78 | 0.74 | Subset-2 |
| GW_94 | RW3 - SUBSOIL | 0.63 | 0.67 | Subset-2 |
| GW_95 | SHRULE GWL | 0.47 | 0.55 | Subset-2 |
| GW_96 | SLIEVEROE BH1 | 0.92 | 0.82 | Subset-1 |
| GW_97 | TONYSTACKAN (CLERKINS) | 0.74 | 0.65 | Subset-2 |
| GW_98 | TULLY | 0.41 | 0.53 | Subset-2 |
| GW_99 | TURROCK | 0.88 | 0.79 | Subset-1 |
| GW_100 | VICKERSTOWN | 0.74 | 0.71 | Subset-2 |
