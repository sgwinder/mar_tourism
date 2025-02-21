### 
### MAR Final Visitation Model
### 3/26/20
###

### Forking from viz_model.R to make a cleaner script
### Updating 7/1/20 to make use of my new cleaner preparing predictors scripts

library(tidyverse)
library(corrgram)
library(coefplot)
library(sf)


modplot <- function(x){
  par(mfrow = c(2,2))
  plot(x, ask = F)
  par(mfrow = c(1,1))
}

setwd("~/Documents/MAR/mar_tourism/Data/")

# read in the prepared predictors
aoi_viz_exp <- read_sf("../../ModelRuns/baseline_20200715/aoi_viz_exp.shp")
predictors <- read_csv("NonClimatePredictors_20210204.csv")
climatepreds <- read_csv("Future_Climate_RCP85_2050s_and_Current.csv")

est_vis <- aoi_viz_exp %>%
  st_set_geometry(NULL) %>%
  dplyr::select(pid, est_vis) %>%
  mutate(vis_log = log1p(est_vis))

## drop pids that are slivers
#slivers <- read_csv("../../AOI/AOI_v3/Intersected/slivers.csv")

# combining, using baseline climate
pred_small <- est_vis %>%
  left_join(predictors) %>%
  left_join(climatepreds %>% dplyr::select(pid, temp = temp0, hotdays = hotdays0, precip = precip0)) %>%
  filter(!is.na(precip)) 
summary(pred_small)

# why do I have negative hotdays? Tracked this back to my rasterizing step.
# TODO: replace these with zeros. But I don't think this has a big impact on anything,
# so leaving as is for now

# look at forest
#predsSF <- aoi_viz_exp %>% left_join(predictors)
#ggplot(predsSF) + geom_sf(aes(fill = forest))


#### Exploring variables
# first limiting those I display & mutating to reflect what's actually going into model
#pred_small <- predictors %>%
 # filter(!is.na(est_vis), !pid %in% slivers$pid, !is.na(temp)) %>%
  #dplyr::select(pid, vis_log, est_vis, 
   #             country = Country, 
    #            corals, mangroves, beach, forest, temp, dayshot,
     #           precip, #protected, prop_land, 
      #          wildlife, #C3P, air_min_dist, ports_min_dist, 
       #         pa_min_dist, ruins, #sargassum, 
        #        roads_min_dist,
         #       prop_dev) %>%
  #mutate(developed = as.integer(prop_dev > 0),
   #      roads = as.integer(roads_min_dist == 0)) %>%
  #dplyr::select(-roads_min_dist, -prop_dev)
#corrgram(pred_small, upper.panel = panel.pts, lower.panel = panel.cor, diag.panel = panel.density)

# examining climate only
#corrgram(pred_small %>% dplyr::select(vis_log, temp, hotdays, precip), upper.panel = panel.pts, lower.panel = panel.cor)

# examing coral only
#corrgram(pred_small %>% dplyr::select(starts_with("coral")), upper.panel = panel.pts, lower.panel = panel.cor)


# does it work if I drop all NAs? And rescale to get everything 0-1?
scale_func <- function(x) (x - min(x))/(max(x) - min(x))
pred_scaled <- pred_small %>% 
  #filter(!is.na(est_vis) & !is.na(temp)) %>%
  mutate(temp = scale_func(temp),
         hotdays = scale_func(hotdays),
         precip = scale_func(precip),
         pa_min_dist = scale_func(pa_min_dist),
         cellarea = scale_func(cellarea))
summary(pred_scaled)

vis_model <- lm(vis_log ~ country + coral_prop + mangrove_prop + beach + forest_prop + temp + I(temp^2) + 
              hotdays + precip  + 
                wildlife +
              pa_min_dist + ruins  + develop + roads + cellarea, 
            data = pred_scaled)
(vm_sum <- summary(vis_model))
# .445 vs .449
# cellarea seems to be an important controlling variable (sig, and brings me from .44 to .467)
modplot(vis_model)
coefplot(vis_model, decreasing = TRUE)
car::vif(vis_model)

# plotting fitted values annd residuals
modcheck <- pred_scaled
modcheck$fitted <- vis_model$fitted.values
modcheck$resids <- vis_model$residuals

modchecksp <- aoi_viz_exp %>% 
  dplyr::select(pid, geometry) %>%
  left_join(modcheck, by = "pid")

ggplot(modchecksp) + geom_sf(aes(fill = vis_log), size = .1)
ggplot(modchecksp) + geom_sf(aes(fill = fitted), size = .1)
ggplot(modchecksp) + geom_sf(aes(fill = resids), size = .1) + scale_fill_distiller(palette = "RdBu")



# plotting indiv relationships
ggplot(pred_small) +
  geom_point(aes(x = temp, y = vis_log), alpha = .2)

ggplot(pred_small) +
  geom_point(aes(x = hotdays, y = vis_log), alpha = .2)

ggplot(pred_small) +
  geom_point(aes(x = jitter(precip), y = vis_log), alpha = .2)



### Ok. I'd like to get a marginal effect plot for temperature
# First, need to create a df that has mean values for everything else, but a range for temp.
# (also, will need to retransform out of the scaled values)
#... actually, since I'm not comparing magnitudes right now, I'll just rebuild the model using raw values and predict from that
vis_model_raw <- lm(vis_log ~ country + coral_prop + mangrove_prop + beach + forest_prop + temp + I(temp^2) + 
                      hotdays + precip  + 
                      wildlife +
                      pa_min_dist + ruins  + develop + roads + cellarea, 
                data = pred_small)
summary(vis_model_raw)

# let's write out the predictors and model objects for both of these and track them. Also let's write out the model summaries
sink("../Models/vis_model_scaled_summary.txt")
summary(vis_model)

sink("../Models/viz_model_raw_summary.txt")
summary(vis_model_raw)
sink()

write_csv(pred_small, "Predictors_Baseline.csv")
write_csv(pred_scaled, "Predictors_Baseline_scaled.csv")

write_rds(vis_model, "../Models/viz_model_scaled.rds")
write_rds(vis_model_raw, "../Models/viz_model_raw.rds")


