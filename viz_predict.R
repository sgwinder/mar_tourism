#####
### Using the Viz Model to predict Viz under different scenarios
###
### First pass test using the corals layer that Jess created
### 4/20/20 SGW

### Updated 5/19 for new corals tests - also working to generalize
### 7/1 Adding climate

library(tidyverse)
library(sf)
library(lwgeom)
library(raster)
library(fasterize)

## Need to: read in model object, existing predictors,
##    AOI, new data layer, run intersection to get model inputs,
##    scale to match data inputs (relevant for non-binary predictors),
##    create "newdata" df that holds all else equal,
##    predict tourism, write out shapefile

## Additionally, for the ROOT change in service rasters, need to run two scenarios 
##    and subtract them from each other

setwd("~/Documents/MAR/")

baselines <- read_csv("mar_tourism/Data/Predictors_Baseline.csv")
climate_vals <- read_csv("mar_tourism/Data/Future_Climate_RCP85_2050s_and_Current.csv")
viz_model_raw <- read_rds("mar_tourism/Models/viz_model_raw.rds")
aoi <- read_sf("ModelRuns/baseline_20200715/T_AOI_v4_5k_32616_pid.shp")

## Getting oriented in naming scheme

# Starting with Belize Protect forest
country <- "hn"
countryLong <- "Honduras"
ipm <- "ipm_03" #Protect forest
aname <- "prot_fors"
climate <- "clim2" #Baseline climate = clim0; 25th perc = clim1; 75th perc = clim2
climshort <- "c2"

newNonClimate <- read_csv(paste0("ROOT/ProtectForest/NonClimatePredictors_", country, "_", climshort, ".csv"))

# import empty country raster & country aoi outline
country_rast <- raster(paste0("ROOT/CountryAOIs/", country, "_root_aoi.tif"))
country_sf <- read_sf(paste0("ROOT/CountryAOIs/", country, "_root_aoi.shp"))

clim_post <- case_when(climate == "clim0" ~ "0",
                       climate == "clim1" ~ "25",
                       climate == "clim2" ~ "75")

clim_post_c <- case_when(climate == "clim0" ~ "",
                       climate == "clim1" ~ "25",
                       climate == "clim2" ~ "75")

# Now doing Belize protect coral
#ipm <- "climate" #"ipm_06"
#aname <- "noact" #"prot_corl"
#coral_new <- read_sf("ROOT/ROOT_coral_test_20200519/protect_coral_Tourism_CVmodel/MAR_coral_WGS8416N_eraseBelize.shp")

modeled <- baselines %>%
  dplyr::select(pid, vis_log, est_vis) 

#### Joining climate onto baselines
base_climate_all <- baselines %>%
  left_join(climate_vals, by = "pid")

### Create tibble of baseline values in new climate
base_clim_data <- base_climate_all %>%
  dplyr::select(country, 
                coral_prop = paste0("coral_prop", clim_post_c), 
                mangrove, 
                beach,
                forest_prop, 
                temp = paste0("temp", clim_post), 
                hotdays = paste0("hotdays", clim_post), 
                precip = paste0("precip", clim_post), 
                wildlife,
                pa_min_dist, 
                ruins, 
                develop, 
                roads,
                cellarea)

preds_base_clim <- predict(viz_model_raw, newdata = base_clim_data)
modeled$preds_base_clim <- preds_base_clim
modeled$preds_base_clim_vis <- expm1(preds_base_clim)
modeled

# Create tibble of SCENARIO data in new climate
scen_climate_all <- newNonClimate %>%
  left_join(climate_vals, by = "pid")
scen_climate_all

scen_clim_data <- scen_climate_all %>%
  dplyr::select(country, 
                coral_prop, #= paste0("coral_prop", clim_post_c), 
                mangrove, 
                beach,
                forest_prop, 
                temp = paste0("temp", clim_post), 
                hotdays = paste0("hotdays", clim_post), 
                precip = paste0("precip", clim_post), 
                wildlife,
                pa_min_dist, 
                ruins, 
                develop, 
                roads,
                cellarea)

preds_scen_clim <- predict(viz_model_raw, newdata = scen_clim_data)
modeled$preds_scen_clim <- preds_scen_clim
modeled$preds_scen_clim_vis <- expm1(preds_scen_clim)
modeled



# calculate difference
modeled <- modeled %>%
  mutate(diff_vis = round(preds_base_clim_vis - preds_scen_clim_vis, 2)) # need to be careful about this line and what it means for each scenario
modeled

# join to spatial 
modeled_sp <- aoi %>%
  dplyr::select(pid, CNTRY_NAME) %>%
  left_join(modeled, by = "pid")

ggplot(modeled_sp) +
  geom_sf(aes(fill = diff_vis), size = .1)

# subset to country
modeled_country <- modeled_sp %>% filter(CNTRY_NAME == countryLong)

# check it out
ggplot(modeled_country) +
  geom_sf(aes(fill = diff_vis))

modeled_country
summary(modeled_country$diff_vis)

## Extract the modeled estimates and difference and write it out
country_clean <- modeled_country %>%
  dplyr::select(pid, CNTRY_NAME, est_vis, preds_base_clim_vis, preds_scen_clim_vis, diff_vis)

# write out shp
st_write(country_clean, paste0("ROOT/ProtectForest/IPMs/", country, "_", ipm, "_", aname, "_rec_", climate, ".geojson"))#, delete_dsn = TRUE)


  
### Convert to Raster (todo: update with new empty raster that Jade shared)
#bz_rast
#crs(bz_rast)
#dataType(bz_rast)
#plot(country_rast)

# raster type to float 32 is what matthew thinks will help
# transform
country_tran <- st_transform(country_clean, crs = 26916) 

diff_rast <- fasterize(country_tran, country_rast, field = "diff_vis", background = 0)
diff_rast
#plot(diff_rast)
#dataType(diff_rast) <- "FLT4S"
#dataType(diff_rast)

# mask it
# NOTE: if this throws strange errors/warnings, go to `tmp/R******` and delete all the temp rasters that have been created
diff_masked <- mask(diff_rast, mask = country_sf, datatype = "FLT4S")
diff_masked

#writeRaster(diff_masked, "ROOT/ProtectForest/IPMs/test.tif", format = "GTiff", datatype = "FLT4S", overwrite = TRUE)

# write it out
writeRaster(diff_masked, 
            paste0("ROOT/ProtectForest/IPMs/", country, "_", ipm,"_", aname, "_rec_", climate, ".tif"), 
            format = "GTiff", datatype = "FLT4S", overwrite = TRUE)



