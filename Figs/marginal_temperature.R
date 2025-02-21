###
### Making a marginal plot for temperature 
### (to identify "peak" temp)

### Forked from bottom of viz_model_clean.R on 7/29/20

library(tidyverse)
library(stringr)

setwd("~/Documents/MAR/mar_tourism/")

pred_small <- read_csv("Data/Predictors_Baseline.csv")
viz_model_raw <- read_rds("Models/viz_model_raw.rds")

pred_small

## marginal plot for temp
newdata_temp <- tibble(temp = seq(min(pred_small$temp, na.rm = T), 30, length.out = 50),
                       country = "Belize",
                       coral_prop = 1,
                       mangrove_prop = 1,
                       beach = 1,
                       forest_prop = 1,
                       hotdays = min(pred_small$hotdays, na.rm = T),
                       precip = mean(pred_small$precip, na.rm = T),
                       wildlife = 1,
                       pa_min_dist = mean(pred_small$pa_min_dist),
                       ruins = 1,
                       develop = 0,
                       roads = 0,
                       cellarea = max(pred_small$cellarea))

newdata_temp$preds <- predict(viz_model_raw, newdata = newdata_temp)
newdata_temp$preds_vis <- expm1(newdata_temp$preds)
newdata_temp

# note that plotting the points here is not fair, since the line is assuming mean values of many other things
ggplot(newdata_temp) +
  geom_line(aes(x = temp, y = preds_vis)) +
  #  geom_point(data = pred_small, aes(x = temp, y = est_vis)) +
  # scale_y_log10() +
  theme_classic()

newdata_temp %>%
  arrange(desc(preds_vis))
# peak vis at 24.6 # 24.7 as of 5/28/21
# this is invariant to changes in newdata, which just shift the line up or down, not side to side

## let's compare this marginal plot to our future temp data
climate_vals <- read_csv("Data/Future_Climate_RCP85_2050s_and_Current.csv")
climate_vals
climate_tall <- climate_vals %>%
  pivot_longer(-pid,
               names_to = c("variable", "climate"), 
               names_pattern = "([a-z]*)([0-9]*)",
               values_to = "measure")
climate_tall


ggplot(newdata_temp) +
  geom_line(aes(x = temp, y = preds_vis)) +
  #geom_rug(data = pred_small, aes(x = temp, y = est_vis)) +
  geom_rug(data = climate_tall %>% filter(variable == "temp"), aes(x = measure, col = climate)) +
  # scale_y_log10() +
  scale_y_continuous(limits = c(0, NA)) +
  theme_classic()


#### Let's do a marginal plot for precip
newdata_precip <- tibble(precip = seq(min(pred_small$precip, na.rm = T), max(pred_small$precip, na.rm = T), length.out = 50),
                         country = "Belize",
                         coral_prop = 1,
                         mangrove_prop = 1,
                         beach = 1,
                         forest_prop = 1,
                         hotdays = min(pred_small$hotdays, na.rm = T),
                         temp = mean(pred_small$temp, na.rm = T),
                         wildlife = 1,
                         pa_min_dist = mean(pred_small$pa_min_dist),
                         ruins = 1,
                         develop = 0,
                         roads = 0,
                         cellarea = max(pred_small$cellarea))

newdata_precip$preds <- predict(viz_model_raw, newdata = newdata_precip)
newdata_precip$preds_vis <- expm1(newdata_precip$preds)
newdata_precip

# note that plotting the points here is not fair, since the line is assuming mean values of many other things
ggplot(newdata_precip) +
  geom_line(aes(x = precip, y = preds_vis)) +
  geom_rug(data = climate_tall %>% filter(variable == "precip"), aes(x = measure, col = climate)) +
  # geom_point(data = pred_small, aes(x = precip, y = est_vis)) +
  scale_y_continuous(limits = c(0, NA)) +
  #  scale_y_log10() +
  theme_classic()

### hot days
newdata_hotdays <- tibble(hotdays = seq(min(pred_small$hotdays, na.rm = T), max(pred_small$hotdays, na.rm = T), length.out = 50),
                         country = "Belize",
                         coral_prop = 1,
                         mangrove_prop = 1,
                         beach = 1,
                         forest_prop = 1,
                         precip = mean(pred_small$precip, na.rm = T),
                         temp = mean(pred_small$temp, na.rm = T),
                         wildlife = 1,
                         pa_min_dist = mean(pred_small$pa_min_dist),
                         ruins = 1,
                         develop = 0,
                         roads = 0,
                         cellarea = max(pred_small$cellarea))

newdata_hotdays$preds <- predict(viz_model_raw, newdata = newdata_hotdays)
newdata_hotdays$preds_vis <- expm1(newdata_hotdays$preds)
newdata_hotdays

# let's do the same but extending out to where we're predicting
newdata_hotdays_ext <- tibble(hotdays = seq(min(pred_small$hotdays, na.rm = T), 178, length.out = 50),
                          country = "Belize",
                          coral_prop = 1,
                          mangrove_prop = 1,
                          beach = 1,
                          forest_prop = 1,
                          precip = mean(pred_small$precip, na.rm = T),
                          temp = mean(pred_small$temp, na.rm = T),
                          wildlife = 1,
                          pa_min_dist = mean(pred_small$pa_min_dist),
                          ruins = 1,
                          develop = 0,
                          roads = 0,
                          cellarea = max(pred_small$cellarea))

newdata_hotdays_ext$preds <- predict(viz_model_raw, newdata = newdata_hotdays_ext)
newdata_hotdays_ext$preds_vis <- expm1(newdata_hotdays_ext$preds)
newdata_hotdays_ext


# trying to add lines for the range of hot days in each climate piece
climate_ranges <- climate_tall %>%
  group_by(variable, climate) %>%
  summarise(min = min(measure), max = max(measure)) %>%
  ungroup() %>%
  mutate(location = rep(c(1000000, 750000, 500000), 3))

climate_ranges

# note that plotting the points here is not fair, since the line is assuming mean values of many other things
ggplot(newdata_hotdays) +
  geom_line(data = newdata_hotdays_ext, aes(x = hotdays, y = preds_vis), linetype = 2) +
  geom_line(aes(x = hotdays, y = preds_vis)) +
  #geom_rug(data = climate_tall %>% filter(variable == "hotdays"), aes(x = measure, col = climate)) +
  geom_errorbar(data = climate_ranges %>% filter(variable == "hotdays"), 
                 aes(xmin = 0, xmax = max, y = location, col = climate)) +
  # geom_point(data = pred_small, aes(x = hotdays, y = est_vis)) +
  #  scale_y_log10() +
  scale_y_continuous(limits = c(0, NA), name = "Visitors", breaks = NULL) +
  scale_x_continuous(limits = c(0, NA), name = "Days above 35C") +
  scale_color_discrete(name = "Climate", labels = c("Current", "25th Percentile (2050s)", "75th Percentile (2050s)")) +
  theme_classic()

#ggsave("../Deliverables/figs/ClimateMaps/hotdays_relationship_and_ranges.png", width = 6, height = 4, units = "in")

## this looks really good. can/should I do the same for other variables? maybe wait and see
