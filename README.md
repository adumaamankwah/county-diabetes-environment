# Diabetes Prevalence and Environmental Determinants Across U.S. Counties

A county-level secondary analysis of how adult diabetes prevalence relates to **food environment quality** and **access to exercise opportunities** across more than 3,000 U.S. counties. The data come from the 2025 County Health Rankings & Roadmaps.

**Author:** Nana Ama Aduma Amankwah, MBChB, MPH

## Key findings

| Exposure vs. % adults with diabetes | Counties | Pearson r (95% CI) | p |
|---|---|---|---|
| Food Environment Index | 3,100 | −0.61 (−0.63 to −0.59) | < 0.001 |
| % lacking access to exercise opportunities | 3,097 | 0.29 (0.26 to 0.32) | < 0.001 |

- Poorer food environments were strongly associated with higher diabetes prevalence. Mean adult diabetes prevalence was **13.1%** in the lowest Food Environment Index quartile and **9.3%** in the highest.
- Limited exercise access was modestly associated with higher diabetes prevalence. Mean prevalence was **12.0%** in the quartile with the least access and **10.3%** in the quartile with the most.

These are ecological, cross-sectional associations at the county level. They do not establish causation or apply to individuals.

## Data

- **Source:** [County Health Rankings & Roadmaps](https://www.countyhealthrankings.org), 2025 release, file `2025 County Health Rankings Data - v3.xlsx`
- **Measures used:**
  - `% Adults with Diabetes` (Additional Measure Data sheet)
  - `Food Environment Index`, scored 0–10 where higher means a better food environment (Select Measure Data sheet)
  - `% With Access to Exercise Opportunities` (Select Measure Data sheet)
- **Unit of analysis:** U.S. county. National and state summary rows are excluded.

The data file is not included in this repository. It is publicly available from the County Health Rankings website.

## Methods

1. Merged the two data sheets by county FIPS code and kept county rows only.
2. Derived `% lacking access to exercise opportunities` as 100 minus `% with access`.
3. Calculated descriptive statistics for each measure.
4. Tested associations with Pearson correlation and 95% confidence intervals, using complete cases. Spearman correlation was run as a sensitivity check.
5. Compared mean diabetes prevalence across quartiles of each exposure.
6. Produced scatterplots with linear fit lines and county-level choropleth maps using `usmap`.

## How to run

Requirements: R (version 4.1 or later). Missing packages install automatically when the script runs.

```bash
# 1. Download "2025 County Health Rankings Data - v3.xlsx" and place it in ./data
# 2. From this folder:
Rscript analysis.R
```

## Outputs

```
output/
├── tables/
│   ├── county_analytic_dataset.csv
│   ├── descriptive_statistics.csv
│   ├── correlation_results.csv
│   └── diabetes_by_quartile.csv
├── figures/
│   ├── scatter_fei_vs_diabetes.png
│   ├── scatter_exercise_vs_diabetes.png
│   ├── map_diabetes.png
│   ├── map_food_environment.png
│   ├── map_exercise_access.png
│   └── map_lack_exercise_access.png
└── session_info.txt
```

## Citation

Amankwah, N. A. A. (2025). *Diabetes prevalence and environmental determinants across U.S. counties* [Computer software]. GitHub.

Data: University of Wisconsin Population Health Institute. *County Health Rankings & Roadmaps 2025.* www.countyhealthrankings.org
