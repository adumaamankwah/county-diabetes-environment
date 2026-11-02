# =============================================================================
# Diabetes Prevalence and Environmental Determinants Across U.S. Counties
# Data: 2025 County Health Rankings & Roadmaps (University of Wisconsin
#       Population Health Institute)
# Author: Nana Ama Aduma Amankwah, MBChB, MPH
#
# Purpose:
#   Assess county-level associations between adult diabetes prevalence and
#   (1) food environment quality (Food Environment Index) and
#   (2) access to exercise opportunities.
#
# Outputs (written to ./output):
#   tables/descriptive_statistics.csv
#   tables/correlation_results.csv
#   tables/diabetes_by_quartile.csv
#   tables/county_analytic_dataset.csv
#   figures/ scatterplots (2) and county choropleth maps (4), PNG, 300 dpi
#
# Usage:
#   1. Download "2025 County Health Rankings Data - v3.xlsx" from
#      https://www.countyhealthrankings.org and place it in ./data
#   2. From the repository folder, run:  Rscript analysis.R
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
pkgs <- c("readxl", "janitor", "dplyr", "tidyr", "stringr", "ggplot2",
          "usmap", "scales")
missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
invisible(lapply(pkgs, library, character.only = TRUE))

data_file <- file.path("data", "2025 County Health Rankings Data - v3.xlsx")
fig_dir   <- file.path("output", "figures")
tab_dir   <- file.path("output", "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(data_file)) {
  stop("Data file not found. Place '2025 County Health Rankings Data - v3.xlsx' in ./data")
}

# ---- 1. Load data ------------------------------------------------------------
# Column headers are on row 2 of each data sheet, so skip the first row.
sel <- read_excel(data_file, sheet = "Select Measure Data", skip = 1) %>%
  clean_names()
add <- read_excel(data_file, sheet = "Additional Measure Data", skip = 1) %>%
  clean_names()

# ---- 2. Build analytic dataset ----------------------------------------------
df <- sel %>%
  select(fips, state, county,
         food_environment_index,
         percent_with_access_to_exercise_opportunities) %>%
  left_join(add %>% select(fips, percent_adults_with_diabetes), by = "fips") %>%
  mutate(
    fips = str_pad(as.character(fips), width = 5, side = "left", pad = "0"),
    across(c(food_environment_index,
             percent_with_access_to_exercise_opportunities,
             percent_adults_with_diabetes), as.numeric)
  ) %>%
  # Keep counties only: drop national and state summary rows
  filter(!is.na(county), !str_ends(fips, "000")) %>%
  transmute(
    fips, state, county,
    diabetes       = percent_adults_with_diabetes,
    fei            = food_environment_index,
    access_ex      = percent_with_access_to_exercise_opportunities,
    lack_access_ex = 100 - percent_with_access_to_exercise_opportunities
  )

cat("Counties in analytic dataset:", nrow(df), "\n")
cat("States (incl. DC):", n_distinct(df$state), "\n\n")
write.csv(df, file.path(tab_dir, "county_analytic_dataset.csv"), row.names = FALSE)

# ---- 3. Descriptive statistics ----------------------------------------------
desc <- df %>%
  select(diabetes, fei, access_ex, lack_access_ex) %>%
  pivot_longer(everything(), names_to = "variable") %>%
  group_by(variable) %>%
  summarise(
    n       = sum(!is.na(value)),
    missing = sum(is.na(value)),
    mean    = mean(value, na.rm = TRUE),
    sd      = sd(value, na.rm = TRUE),
    median  = median(value, na.rm = TRUE),
    q1      = quantile(value, 0.25, na.rm = TRUE),
    q3      = quantile(value, 0.75, na.rm = TRUE),
    min     = min(value, na.rm = TRUE),
    max     = max(value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric) & !c(n, missing), ~ round(.x, 2)))

print(desc)
write.csv(desc, file.path(tab_dir, "descriptive_statistics.csv"), row.names = FALSE)

# ---- 4. Correlations (Pearson, with Spearman as sensitivity check) ----------
run_cor <- function(x, label) {
  d  <- df %>% select(all_of(c(x, "diabetes"))) %>% na.omit()
  pt <- cor.test(d[[x]], d$diabetes, method = "pearson")
  sp <- suppressWarnings(cor.test(d[[x]], d$diabetes, method = "spearman"))
  fit <- lm(d$diabetes ~ d[[x]])
  data.frame(
    exposure     = label,
    n_counties   = nrow(d),
    pearson_r    = round(unname(pt$estimate), 3),
    ci_lower_95  = round(pt$conf.int[1], 3),
    ci_upper_95  = round(pt$conf.int[2], 3),
    t_statistic  = round(unname(pt$statistic), 2),
    df           = unname(pt$parameter),
    p_value      = signif(pt$p.value, 3),
    r_squared    = round(unname(pt$estimate)^2, 3),
    slope        = round(coef(fit)[2], 3),
    spearman_rho = round(unname(sp$estimate), 3)
  )
}

cor_results <- bind_rows(
  run_cor("fei",            "Food Environment Index"),
  run_cor("access_ex",      "% with access to exercise opportunities"),
  run_cor("lack_access_ex", "% lacking access to exercise opportunities")
)
print(cor_results)
write.csv(cor_results, file.path(tab_dir, "correlation_results.csv"), row.names = FALSE)

# ---- 5. Diabetes prevalence by exposure quartile -----------------------------
quartile_table <- function(x, label) {
  df %>%
    filter(!is.na(.data[[x]]), !is.na(diabetes)) %>%
    mutate(quartile = ntile(.data[[x]], 4)) %>%
    group_by(quartile) %>%
    summarise(n_counties = n(),
              mean_diabetes_pct = round(mean(diabetes), 2),
              .groups = "drop") %>%
    mutate(exposure = label,
           quartile = paste0("Q", quartile,
                             ifelse(quartile == 1, " (lowest)",
                                    ifelse(quartile == 4, " (highest)", ""))))
}

quartiles <- bind_rows(
  quartile_table("fei",            "Food Environment Index"),
  quartile_table("lack_access_ex", "% lacking access to exercise opportunities")
) %>% select(exposure, quartile, n_counties, mean_diabetes_pct)
print(quartiles)
write.csv(quartiles, file.path(tab_dir, "diabetes_by_quartile.csv"), row.names = FALSE)

# ---- 6. Scatterplots ---------------------------------------------------------
caption_txt <- "Data: 2025 County Health Rankings & Roadmaps"

scatter_plot <- function(x, xlab, title, colour, outfile) {
  d <- df %>% select(all_of(c(x, "diabetes"))) %>% na.omit()
  r <- cor(d[[x]], d$diabetes)
  p <- ggplot(d, aes(x = .data[[x]], y = diabetes)) +
    geom_point(alpha = 0.45, size = 1.2, colour = colour) +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE,
                colour = "darkred", linewidth = 1) +
    annotate("text", x = -Inf, y = Inf, hjust = -0.1, vjust = 1.5,
             label = sprintf("r = %.2f, p < 0.001\nn = %s counties",
                             r, format(nrow(d), big.mark = ","))) +
    labs(title = title, x = xlab, y = "% Adults with Diabetes",
         caption = caption_txt) +
    theme_minimal(base_size = 13)
  ggsave(file.path(fig_dir, outfile), p, width = 8, height = 5.5,
         dpi = 300, bg = "white")
}

scatter_plot("fei",
             "Food Environment Index (higher = better food access)",
             "Food Environment Index vs. Diabetes Prevalence, U.S. Counties (2025)",
             "seagreen", "scatter_fei_vs_diabetes.png")

scatter_plot("lack_access_ex",
             "% Lacking Access to Exercise Opportunities",
             "Lack of Exercise Access vs. Diabetes Prevalence, U.S. Counties (2025)",
             "steelblue", "scatter_exercise_vs_diabetes.png")

# ---- 7. County choropleth maps ----------------------------------------------
county_map <- function(var, low, high, legend, title, outfile) {
  p <- plot_usmap(data = df %>% select(fips, all_of(var)),
                  values = var, color = "white", linewidth = 0.05) +
    scale_fill_continuous(low = low, high = high, name = legend,
                          label = scales::comma, na.value = "grey85") +
    labs(title = title,
         caption = paste0(caption_txt, ". Grey = data not available.")) +
    theme(legend.position = "right")
  ggsave(file.path(fig_dir, outfile), p, width = 10, height = 6,
         dpi = 300, bg = "white")
}

county_map("diabetes", "lightyellow", "darkred", "% Adults with Diabetes",
           "Diabetes Prevalence by U.S. County (2025)",
           "map_diabetes.png")
county_map("fei", "lightyellow", "darkgreen", "Food Environment Index",
           "Food Environment Index by U.S. County (2025; higher = better food access)",
           "map_food_environment.png")
county_map("access_ex", "lightyellow", "darkblue", "% With Access to Exercise",
           "Access to Exercise Opportunities by U.S. County (2025)",
           "map_exercise_access.png")
county_map("lack_access_ex", "#e0f7fa", "#006064", "% Lacking Exercise Access",
           "Lack of Access to Exercise Opportunities by U.S. County (2025)",
           "map_lack_exercise_access.png")

cat("\nDone. Tables in", tab_dir, "and figures in", fig_dir, "\n")
writeLines(capture.output(sessionInfo()), file.path("output", "session_info.txt"))
