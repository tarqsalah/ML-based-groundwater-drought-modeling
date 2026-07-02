# =============================================================================
# Standardised Groundwater Index (SGI) — Monthly Drought Analysis
#
# Computes monthly SGI per groundwater monitoring station from groundwater-level
# records, classifies SGI severity, summarises drought events, and produces
# per-station GWL/SGI plots and a drought-event timeline.
#
# Inputs (working directory):
#   complete_GWL_data.csv   — groundwater levels (Date + one column per station)
#   station_guide.csv       — station code -> station name lookup
# Outputs (../outputs/):
#   GWL_SGI_plots.pdf, complete_SGI_monthly.csv, complete_drought_analysis.csv
# =============================================================================

# 1. Import libraries
library(tidyverse)
library(lubridate)
library(patchwork)

# 2. Import data sets
gwl.data      <- read.csv("complete_GWL_data.csv") %>% as_tibble()
stations.data <- read.csv("station_guide.csv")
gw.stations   <- stations.data$code

# 3. Convert date to Date data type
gwl.data$Date <- as.Date(gwl.data$Date)

# 4. Explore data
summary(gwl.data)
summary(stations.data)

# 5. Initiate lists to store results
sgi.list     <- list()
drought.list <- list()

# 6. Open a PDF device
pdf("../outputs/GWL_SGI_plots.pdf", width = 12, height = 8)

# 7. Loop over stations to calculate SGI values
for (gw in gw.stations) {

    # filter station name
    station.name <- stations.data %>%
        filter(code == gw) %>%
        pull(gw.station)

    #___________________________SGI calculator__________________________________

    # calculate monthly GWL
    gwl.monthly <- gwl.data %>%
        select(date = Date, all_of(gw)) %>%
        rename(gwl.value = all_of(gw)) %>%
        mutate(year = year(date), month = month(date)) %>%
        group_by(year, month) %>%
        summarise(date = first(date), gwl.value = mean(gwl.value), .groups = "drop")

    # Calculate SGI on monthly ranking
    sgi.monthly <- gwl.monthly %>%
        group_by(month) %>%
        mutate(rank = rank(gwl.value),
               standardised.rank = rank / (n() + 1),
               sgi = qnorm(standardised.rank),
               code = gw) %>%
        ungroup() %>%
        mutate(station.name = station.name,
               event = factor(case_when(between(sgi,-3, -2) ~ "Extreme",
                                        between(sgi,-1.99, -1.50) ~ "Severe",
                                        between(sgi,-1.49, -1.00) ~ "Moderate",
                                        between(sgi, -0.99, 0) ~ "Mild",
                                        between(sgi, 0, 3) ~ "Normal")))
    #_______________________________Plots_______________________________________

    # GWL plot
    gwl.plot <- ggplot(gwl.monthly, aes(x = date, y = gwl.value)) +
        geom_line() +
        labs(title = paste0(station.name, " (", gw, ")"), y = "GWL (m aSL)") +
        theme_bw() +
        theme(axis.title.x = element_blank(),
              axis.text.x  = element_blank(),
              axis.ticks.x = element_blank())

    # SGI plot (threshold line and shading aligned to the drought threshold, -1.5)
    sgi.plot <- ggplot(sgi.monthly, aes(x = date, y = sgi)) +
        geom_line() +
        labs(x = "Date", y = "Monthly SGI") +
        scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
        geom_hline(yintercept = -1.5, color = "black", linetype = "dashed") +
        geom_ribbon(aes(ymin = ifelse(sgi < -1.5, sgi, NA), ymax = -1.5),
                    fill = "red", alpha = 0.7) +
        theme_bw()

    combined.plot <- gwl.plot / sgi.plot

    # write the combined plot to the open PDF device
    print(combined.plot)

    #______________________________Drought Analysis_____________________________

    # Group consecutive months of the same severity into events.
    drought.data <- sgi.monthly %>%
        select(date, event) %>%
        arrange(date) %>%
        mutate(next.event = event != lag(event, default = first(event)),
               event.code = cumsum(next.event)) %>%
        group_by(event.code) %>%
        summarise(event        = first(event),
                  start.date   = first(date),
                  end.date     = last(date),
                  year         = year(start.date),
                  duration     = as.numeric(difftime(end.date, start.date, units = "days")) + 1,
                  station.name = station.name,   # scalar from the loop scope
                  code         = gw,             # scalar from the loop scope
                  .groups      = "drop")

    # store results for the current station
    drought.list[[gw]] <- drought.data
    sgi.list[[gw]]     <- sgi.monthly
}

# 8. close the PDF device
dev.off()

#_______________________________________________________________________________

# 9. Store all stations' SGI in a single data frame
sgi.complete <- bind_rows(sgi.list) %>%
    mutate(station.name = factor(station.name, levels = rev(unique(station.name))))

write.csv(sgi.complete, "../outputs/complete_SGI_monthly.csv", row.names = FALSE)

# 10. Combine all drought results into a single data frame
complete.drought.results <- bind_rows(drought.list) %>%
    mutate(station.name = factor(station.name, levels = rev(unique(station.name))))

write.csv(complete.drought.results, "../outputs/complete_drought_analysis.csv", row.names = FALSE)

#_______________________________________________________________________________
# Drought analysis
#
# Drought definition used throughout: SGI <= -1.5, i.e. "Severe"
# To restrict drought to "Severe" only, change this single line to c("Severe").
drought.levels <- c("Severe")

# Number of drought events per year
drought.events.by.year <- complete.drought.results %>%
    filter(event %in% drought.levels) %>%
    group_by(year) %>%
    summarise(events = n(), .groups = "drop")

# Number of drought events during 2018
drought.events.2018 <- complete.drought.results %>%
    filter(year == 2018, event %in% drought.levels) %>%
    summarise(events = n())

# Number of distinct stations in drought during 2018
stations.in.drought.2018 <- complete.drought.results %>%
    filter(year == 2018, event %in% drought.levels) %>%
    summarise(count = n_distinct(station.name)) %>%
    pull(count)

# Drought duration (days) during 2018
drought.duration.2018 <- complete.drought.results %>%
    filter(year == 2018, event %in% drought.levels) %>%
    summarise(min.duration = min(duration), max.duration = max(duration))

#_______________________________________________________________________________
# Temporal distribution of drought events across Irish monitoring stations, 2018
# (dashed lines mark the approximate onset and end of the summer 2018 drought)

ggplot(drought.data, aes(y = station.name, x = start.date)) +
    geom_segment(aes(xend = end.date, yend = station.name, color = event), 
                 linewidth = 1, lineend = "round") +
    scale_x_date(date_labels = "%b%y", date_breaks = "1 month") +
    labs(
        x = "Date",
        y = "Station",
        color = "Groundwater Status") +
    scale_color_manual(values = c("Drought" = "red")) +
    geom_vline(aes(xintercept = as.Date("2018-07-25")), 
               linewidth = 0.5, linetype = "dashed") +
    geom_vline(aes(xintercept = as.Date("2018-05-22")),
               linewidth = 0.5, linetype = "dashed") +
    theme_minimal() +
    theme(axis.text.y = element_text(size = 6), 
          legend.position = c(0.88, 0.96),
          legend.background = element_rect(colour = "black"),
          legend.key.size = unit(0.3, "cm"),   # Reduce legend key size
          legend.text = element_text(size = 7), # Reduce legend text size
          legend.title = element_text(size = 8)) # Reduce legend title size
#_______________________________________________________________________________
