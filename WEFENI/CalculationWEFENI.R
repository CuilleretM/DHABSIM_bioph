# Load required libraries
library(readxl)
library(tidyverse)
library(ggplot2)
library(scales)
library(patchwork)
library(gridExtra)

# Read data from Excel
file_path <- "C:/Users/cuilleret/Documents/gamsdir/projdir/Model_Dahbsim_13_02_2026_App/WEFENI.xlsx"

# Read all sheets
energy_data <- read_excel(file_path, sheet = "repEnergy")
ghg_data <- read_excel(file_path, sheet = "repGHG")
water_data <- read_excel(file_path, sheet = "repWater")
income_data <- read_excel(file_path, sheet = "repIncome")
productivity_data <- read_excel(file_path, sheet = "repProductivity")

# Function to clean and reshape data
clean_data <- function(data, value_name) {
  # Assuming first column is household, second is scenario, third is indicator
  # and remaining columns are years
  data %>%
    rename(
      household = 1,
      scenario = 2,
      indicator = 3
    ) %>%
    # Convert to long format
    pivot_longer(
      cols = -c(household, scenario, indicator),
      names_to = "year",
      values_to = value_name
    ) %>%
    # Clean year (remove any non-numeric characters)
    mutate(
      year = as.numeric(str_extract(year, "\\d{4}")),
      # Convert European decimal format (comma to dot)
      !!value_name := as.numeric(str_replace(!!sym(value_name), ",", "."))
    ) %>%
    select(-indicator)  # Remove indicator column as it's redundant
}

# Clean all datasets
energy_clean <- clean_data(energy_data, "energy")
ghg_clean <- clean_data(ghg_data, "ghg")
water_clean <- clean_data(water_data, "water")
income_clean <- clean_data(income_data, "income")
productivity_clean <- clean_data(productivity_data, "productivity")

# Merge all datasets
all_data <- energy_clean %>%
  full_join(ghg_clean, by = c("household", "scenario", "year")) %>%
  full_join(water_clean, by = c("household", "scenario", "year")) %>%
  full_join(income_clean, by = c("household", "scenario", "year")) %>%
  full_join(productivity_clean, by = c("household", "scenario", "year"))

# Calculate the five indicators
indicators_data <- all_data %>%
  mutate(
    # 1. Energy Footprint = Energy / Productivity MJ/kg
    energy_footprint = energy / (productivity),
    
    # 2. Water Footprint = Water / Productivity m3/ton
    water_footprint = water*10 / (productivity/1000),
    
    # 3. GHG Footprint = GHG / Productivity kgCO2/kg 
    ghg_footprint = ghg / (productivity),
    
    # 4. Productivity (already have it)
    # 5. Income (already have it)
    
    # Additional useful indicators
    total_footprint = energy_footprint + water_footprint + ghg_footprint,
    energy_intensity = energy / income,  # Energy per unit income
    water_intensity = water / income,    # Water per unit income
    ghg_intensity = ghg / income         # GHG per unit income
  )

# Calculate summary statistics by scenario and year
summary_stats <- indicators_data %>%
  group_by(scenario, year) %>%
  summarise(
    # Energy Footprint
    mean_energy_fp = mean(energy_footprint, na.rm = TRUE),
    sd_energy_fp = sd(energy_footprint, na.rm = TRUE),
    median_energy_fp = median(energy_footprint, na.rm = TRUE),
    
    # Water Footprint
    mean_water_fp = mean(water_footprint, na.rm = TRUE),
    sd_water_fp = sd(water_footprint, na.rm = TRUE),
    median_water_fp = median(water_footprint, na.rm = TRUE),
    
    # GHG Footprint
    mean_ghg_fp = mean(ghg_footprint, na.rm = TRUE),
    sd_ghg_fp = sd(ghg_footprint, na.rm = TRUE),
    median_ghg_fp = median(ghg_footprint, na.rm = TRUE),
    
    # Productivity
    mean_productivity = mean(productivity, na.rm = TRUE),
    sd_productivity = sd(productivity, na.rm = TRUE),
    
    # Income
    mean_income = mean(income, na.rm = TRUE),
    sd_income = sd(income, na.rm = TRUE),
    
    # Total Footprint
    mean_total_fp = mean(total_footprint, na.rm = TRUE),
    
    .groups = 'drop'
  )

# Create visualizations for the 5 indicators

# 1. Energy Footprint Visualization
p1 <- ggplot(summary_stats, aes(x = factor(year), y = mean_energy_fp, fill = scenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_errorbar(
    aes(ymin = mean_energy_fp - sd_energy_fp, ymax = mean_energy_fp + sd_energy_fp),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  labs(
    title = "Energy Footprint by Scenario",
    subtitle = "MJ/kg",
    x = "Year",
    y = "Energy Footprint",
    fill = "Scenario"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    legend.position = "bottom"
  ) +
  scale_y_continuous(labels = comma)

# 2. Water Footprint Visualization
p2 <- ggplot(summary_stats, aes(x = factor(year), y = mean_water_fp, fill = scenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_errorbar(
    aes(ymin = mean_water_fp - sd_water_fp, ymax = mean_water_fp + sd_water_fp),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  labs(
    title = "Water Footprint by Scenario",
    subtitle = "m3/ton",
    x = "Year",
    y = "Water Footprint",
    fill = "Scenario"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    legend.position = "bottom"
  ) +
  scale_y_continuous(labels = comma)

# 3. GHG Footprint Visualization
p3 <- ggplot(summary_stats, aes(x = factor(year), y = mean_ghg_fp, fill = scenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_errorbar(
    aes(ymin = mean_ghg_fp - sd_ghg_fp, ymax = mean_ghg_fp + sd_ghg_fp),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  labs(
    title = "GHG Footprint by Scenario",
    subtitle = "kgCO2/kg",
    x = "Year",
    y = "GHG Footprint",
    fill = "Scenario"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    legend.position = "bottom"
  ) +
  scale_y_continuous(labels = comma)

# 4. Productivity Visualization
p4 <- ggplot(summary_stats, aes(x = factor(year), y = mean_productivity, fill = scenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_errorbar(
    aes(ymin = mean_productivity - sd_productivity, ymax = mean_productivity + sd_productivity),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  labs(
    title = "Productivity by Scenario kg",
    x = "Year",
    y = "Productivity",
    fill = "Scenario"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  ) +
  scale_y_continuous(labels = comma)

# 5. Income Visualization
p5 <- ggplot(summary_stats, aes(x = factor(year), y = mean_income, fill = scenario)) +
  geom_col(position = "dodge", alpha = 0.8) +
  geom_errorbar(
    aes(ymin = mean_income - sd_income, ymax = mean_income + sd_income),
    position = position_dodge(width = 0.9),
    width = 0.2
  ) +
  labs(
    title = "Income by Scenario $",
    x = "Year",
    y = "Income",
    fill = "Scenario"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  ) +
  scale_y_continuous(labels = comma)

# Display individual plots
print(p1)
print(p2)
print(p3)
print(p4)
print(p5)

# Combined dashboard of all 5 indicators
combined_plot <- (p1+ theme(legend.position = "none") + p2+ theme(legend.position = "none")) / (p3+ theme(legend.position = "none") + p4+ theme(legend.position = "none")) / p5 +
  plot_annotation(
    title = "WEFENI Indicators Dashboard",
    theme = theme(
      plot.title = element_text(hjust = 0.5, size = 16, face = "bold")
    )
  )

print(combined_plot)

ggsave("C:/Users/cuilleret/Documents/gamsdir/projdir/Model_Dahbsim_13_02_2026_App/wefeni_dashboard.pdf", 
       plot = combined_plot,
       width = 16, 
       height = 14, 
       units = "in",
       device = "pdf",
       bg = "white")

###############################SPIDER PLOT


# Load additional library for spider/radar plots
library(fmsb)
library(scales)
# Prepare data for spider plots
# First, normalize the indicators to a 0-1 scale for better visualization
spider_data <- indicators_data %>%
  group_by(year) %>%
  mutate(
    # Normalize each indicator to 0-1 scale across all scenarios
    energy_fp_norm = (energy_footprint - min(energy_footprint, na.rm = TRUE)) / 
      (max(energy_footprint, na.rm = TRUE) - min(energy_footprint, na.rm = TRUE)),
    water_fp_norm = (water_footprint - min(water_footprint, na.rm = TRUE)) / 
      (max(water_footprint, na.rm = TRUE) - min(water_footprint, na.rm = TRUE)),
    ghg_fp_norm = (ghg_footprint - min(ghg_footprint, na.rm = TRUE)) / 
      (max(ghg_footprint, na.rm = TRUE) - min(ghg_footprint, na.rm = TRUE)),
    productivity_norm = (productivity - min(productivity, na.rm = TRUE)) / 
      (max(productivity, na.rm = TRUE) - min(productivity, na.rm = TRUE)),
    income_norm = (income - min(income, na.rm = TRUE)) / 
      (max(income, na.rm = TRUE) - min(income, na.rm = TRUE))
  ) %>%
  ungroup()

# Calculate mean values for each scenario and year
spider_summary <- spider_data %>%
  group_by(scenario, year) %>%
  summarise(
    Energy = mean(energy_fp_norm, na.rm = TRUE),
    Water = mean(water_fp_norm, na.rm = TRUE),
    GHG = mean(ghg_fp_norm, na.rm = TRUE),
    Productivity = mean(productivity_norm, na.rm = TRUE),
    Income = mean(income_norm, na.rm = TRUE),
    .groups = 'drop'
  )

# Method 1: Using fmsb package (traditional radar charts)
scenarios <- unique(spider_summary$scenario)
years <- unique(spider_summary$year)

# Create a PDF with all spider plots
pdf("C:/Users/cuilleret/Documents/gamsdir/projdir/Model_Dahbsim_13_02_2026_App/spider_plots_all_scenarios.pdf", width = 10, height = 8)

for(s in scenarios) {
  # Filter data for current scenario
  scenario_data <- spider_summary %>%
    filter(scenario == s) %>%
    select(-scenario)
  
  # Prepare data for fmsb (need min and max rows)
  radar_data <- rbind(
    rep(1, ncol(scenario_data) - 1),  # Max values
    rep(0, ncol(scenario_data) - 1),  # Min values
    scenario_data %>% select(-year) %>% as.data.frame()
  )
  
  # Set row names
  rownames(radar_data) <- c("max", "min", paste("Year", years))
  
  # Create radar chart
  radarchart(
    radar_data,
    axistype = 1,
    # Customize colors
    pcol = rainbow(length(years)),  # Line colors
    pfcol = scales::alpha(rainbow(length(years)), 0.3),  # Fill colors with transparency
    plwd = 2,  # Line width
    plty = 1,  # Line type
    # Customize grid
    cglcol = "grey",
    cglty = 1,
    cglwd = 0.8,
    # Customize axis
    axislabcol = "grey",
    caxislabels = seq(0, 1, 0.25),
    calcex = 0.7,
    # Title
    title = paste("Scenario:", s, "- All Indicators"),
    vlcex = 0.8
  )
  
  # Add legend
  legend(
    x = "topright",
    legend = paste("Year", years),
    col = rainbow(length(years)),
    lty = 1,
    lwd = 2,
    bty = "n",
    cex = 0.8
  )
}

dev.off()



