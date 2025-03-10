library(dplyr)
library(sdmTMB)
library(stringr)
library(indexwc)

run_num <- 1

# Load configuration data
url <- "https://raw.githubusercontent.com/pfmc-assessments/indexwc/main/data-raw/configuration.csv"
config_data <- read.csv(url, stringsAsFactors = FALSE)
config_data <- dplyr::filter(config_data,
                             source == "NWFSC.Combo")
# add model index
config_data$index_id <- seq_len(nrow(config_data))

# switch signs on the depth -- negative but pos in data
config_data$max_depth <- -config_data$max_depth
config_data$min_depth <- -config_data$min_depth
# drop out pass_scaled and put in yday instead
config_data$formula <- str_replace(config_data$formula,
                                   "pass_scaled",
                                   "zday + I(zday^2)")
# replace longnames in family
config_data$family <- str_replace(config_data$family, "sdmTMB::", "")
config_data$family <- str_replace(config_data$family, "\\(\\)", "")

# Load data
dat <- readRDS("data/wcgbts.rds")
# add X, Y
dat <- sdmTMB::add_utm_columns(dat,
                               ll_names = c("longitude_dd","latitude_dd"),
                               utm_crs = 32610)

# Filter config data down based on available species
spp <- unique(dat$common_name)
config_data <- config_data[which(spp%in%config_data$species),]

# divide spp into thirds for GH actions
sp <- rep(1:3, length(spp))[1:length(spp)]
indx <- which(sp == run_num)

for (i in 1:length(indx)) {

  sub <- dplyr::filter(dat, common_name == spp[indx[i]]) |>
    dplyr::mutate(zday = (yday - mean(sub$yday)) / sd(sub$yday))
  # apply the year, latitude, and depth filters if used
  sub <- dplyr::filter(sub,
                       latitude_dd >= config_data$min_latitude[i],
                       latitude_dd < config_data$max_latitude[i],
                       year >= config_data$min_year[i],
                       year <= config_data$max_year[i],
                       depth_m >= config_data$min_depth[i],
                       depth_m <= config_data$max_depth[i])

  # make a mesh based on settings in config
  mesh <- sdmTMB::make_mesh(sub, xy_cols = c("X","Y"),
                            n_knots = config_data$knots[i])
  sub$fyear <- as.factor(sub$year) # year as factor

  # fit the model using arguments in configuration file
  fit <- sdmTMB(formula = as.formula(config_data$formula[i]),
                time = "year",
                offset = log(sub$effort),
                mesh = mesh,
                data = sub,
                spatial="on",
                spatiotemporal=list(config_data$spatiotemporal1[i],
                                    config_data$spatiotemporal2[i]),
                anisotropy = config_data$anisotropy[i],
                family = get(config_data$family[i])(),
                share_range = config_data$share_range[i])

  san <- sanity(fit, silent=TRUE)
  saveRDS(san, file=paste0("diagnostics/sanity_",
                           config_data$index[i], ".rds"))

  # make predictions
  wcgbts_grid <- indexwc::california_current_grid
  # first filter the grid like with the data
  wcgbts_grid <- dplyr::filter(wcgbts_grid,
                               latitude >= config_data$min_latitude[i],
                               latitude < config_data$max_latitude[i],
                               depth >= config_data$min_depth[i],
                               depth < config_data$max_depth[i],
                               area_km2_WCGBTS > 0)
  # Add calendar date -- predicting to jul 1
  wcgbts_grid$zday <- (182 - mean(sub$yday)) / sd(sub$yday)
  # add X-Y
  wcgbts_grid <- sdmTMB::add_utm_columns(wcgbts_grid,
                                         ll_names = c("longitude","latitude"),
                                         utm_crs = 32610)

  # replicate grid
  wcgbts_grid <- replicate_df(wcgbts_grid, time_name = "year",
                              time_values = unique(sub$year))
  wcgbts_grid$fyear <- as.factor(wcgbts_grid$year)

  # convert area from km2 to ha
  wcgbts_grid$area_ha <- wcgbts_grid$area_km2_WCGBTS * 100

  # Make coastwide index
  pred_all <- predict(fit, wcgbts_grid, return_tmb_object = TRUE)
  index_all <- get_index(pred_all,
                         area = wcgbts_grid$area_ha,
                         bias_correct = TRUE)
  index_all$index <- "Coastwide"

  # make indices for California
  sub_grid <- dplyr::filter(as.data.frame(wcgbts_grid), split_state=="C")
  pred <- predict(fit, sub_grid, return_tmb_object = TRUE)
  index_CA <- get_index(pred,
                        area = sub_grid$area_ha,
                        bias_correct = TRUE)
  index_CA$index <- "California"

  # make indices for Oregon
  sub_grid <- dplyr::filter(as.data.frame(wcgbts_grid), split_state=="O")
  pred <- predict(fit, sub_grid, return_tmb_object = TRUE)
  index_OR <- get_index(pred,
                        area = sub_grid$area_ha,
                        bias_correct = TRUE)
  index_OR$index <- "Oregon"

  # make indices for Oregon
  sub_grid <- dplyr::filter(as.data.frame(wcgbts_grid), split_state=="W")
  pred <- predict(fit, sub_grid, return_tmb_object = TRUE)
  index_WA <- get_index(pred,
                        area = sub_grid$area_ha,
                        bias_correct = TRUE)
  index_WA$index <- "Washington"

  indices <- rbind(index_all, index_CA, index_OR, index_WA)
  indices$index_id <- config_data$index[i]
  indices$common_name <- sub$common_name[1]
  saveRDS(indices,
          paste0("output/",
                 sub$common_name[1],"_",
                 config_data$index_id[i],".rds"))
}

