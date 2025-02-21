
## Gridded and transforming the AOI for MAR

library(tidyverse)
library(sf)

setwd("~/Documents/MAR/GIS/")

aoi <- read_sf("AOI/AOI_v4/Tourism_AOI_v4.shp")
aoi_countries <- read_sf("AOI/AOI_v4/T_AOI_v4_by_country_smoothed.shp")
mpas <- read_sf("BordersandProtectedAreas/MPA/MPA_Updates_July_2020/MPA_Network_WGS8416N_v3.shp")
st_crs(mpas)

# transform to projected coord system
aoi_32 <- st_transform(aoi, crs = 32616)
aoi_countries_32 <- st_transform(aoi_countries, crs = 32616)

# Make the hexagonal grid across the aoi, then intersect with the border and remove small cells
aoi_hex <- st_make_grid(aoi_32, cellsize = 5000, square = FALSE) 

# remove cells that overlap with the outside of the aoi
within_index <- aoi_hex %>% st_within(aoi_32, sparse = FALSE)
aoi_hex_inner <- st_sf(geometry = aoi_hex, within = within_index) %>%
  filter(within == "TRUE")

# intersect with countries
u_countries <- st_intersection(aoi_countries_32, aoi_hex_inner)
ggplot(u_countries) + geom_sf()
u_countries

# I tried a bunch of things (like st_union) to get the MPA boundaries in here too, but they used all my memory 
# and crashed R. So, I'm writing out these hexes (intersected with the countries), and will union in QGIS


# transform gridded aoi to wgs84 for globalrec
#aoi_wgs <- st_transform(aoi_hex, crs = 4326)
#st_crs(aoi_wgs)


# write it out
#st_write(u_countries, "AOI/AOI_v4/intermediate/T_AOI_v4_5k_countries.shp")

# Then, I loaded the above file into QGIS, and unioned it with the mpas layer (since it wasn't working here)
# Read in the result:

aoi_hex_mpas <- read_sf("AOI/AOI_v4/intermediate/T_AOI_v4_5k_countries_MPAs_32616_v2.shp")

# remove extra columns
aoi_clean <- aoi_hex_mpas %>%
  dplyr::select(CNTRY_NAME, name_2, geometry)

ggplot(aoi_clean) + geom_sf(aes(fill = name_2))

# and any tiny polygons (smaller than 100,000 m2). Full hex is 21,650,635 m2
# This has the pleasing consquence of taking me to 8000 features
aoi_sub <- aoi_clean %>%
  mutate(area = st_area(aoi_clean)) %>%
  #arrange(-area) %>%
  filter(area > units::as_units(100000, "m^2"))
all(st_is_valid(aoi_sub))

#ggplot(smalls) + geom_sf()
#st_write(smalls, "AOI/AOI_v4/intermediate/sliverstest.shp", append = FALSE)

# transform for globalrec
aoi_clean_4326 <- st_transform(aoi_sub, crs = 4326)
all(st_is_valid(aoi_clean_4326))
aoi_4326_valid <- st_make_valid(aoi_clean_4326)
all(st_is_valid(aoi_4326_valid))

# write it out
st_write(aoi_sub, "AOI/AOI_v4/T_AOI_v4_5k.shp", append = FALSE)
st_write(aoi_4326_valid, "AOI/AOI_v4/T_AOI_v4_5k_4326.shp", append = FALSE)
  

  