library(dplyr)
library(surveyjoin)
library(lubridate)

url <- "https://raw.githubusercontent.com/pfmc-assessments/indexwc/main/data-raw/configuration.csv"
config_data <- read.csv(url, stringsAsFactors = FALSE)
config_data <- dplyr::filter(config_data,
                             source == "NWFSC.Combo")

# handful of rockfishes aren't in surveyjoin:
#[1] "aurora rockfish"       "blackgill rockfish"    "chilipepper"
#[4] "greenspotted rockfish" "longspine thornyhead"  "rougheye rockfish"
#[7] "stripetail rockfish"   "yelloweye rockfish"    "yellowtail rockfish"

# Use the surveyjoin data
surveyjoin::cache_data()
surveyjoin::load_sql_data()
dat <- surveyjoin::get_data()

# cut down data for only species in the config file
dat <- dplyr::filter(dat,
                     common_name %in% tolower(config_data$species))

# for illustrative purposes, focus initially on WCGBTS
dat <- dplyr::filter(dat, survey_name == "NWFSC.Combo")

# convert date string to doy
dat$yday <- lubridate::yday(lubridate::ymd(dat$date))

dat <- dplyr::rename(dat, latitude_dd = lat_start,
                     longitude_dd = lon_start) |>
  dplyr::filter(!is.na(longitude_dd),
                !is.na(latitude_dd))
# filter fields for smaller file size
dat <- dplyr::select(dat,
  #event_id,
  common_name,
  year,
  yday,
  depth_m,
  effort,
  catch_weight,
  scientific_name,
  longitude_dd,
  latitude_dd
)
saveRDS(dat, "data/wcgbts.rds")
