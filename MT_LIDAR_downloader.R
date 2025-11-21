#Automate the download of Montana LiDAR derived CHM, DSM, or DTM of a bounding box (your study area).
#Jayden Skelly, 11/19/2025

require(terra)
require(sf)
require(tidyverse)
require(httr)

#Check wd(), two folders will be placed here one to download the other to unzip. Change as needed.
getwd()

#provide a polygon of the boundary to download, must be an .shp Make sure its related shp files such as dbf are in the same direc.
#NOTE: I would not suggest a box larger than a 50km by 50km size. While the files can be downloaded, attempting to reproject/resample/mosaic over this scale requires large amounts of RAM.
bbox <- st_read("C:/Users/jaydenskelly/Documents/OneDrive - Montana State University/Classes/LandscapeEco/project/bbox.shp")

#put quad map in temp directory (downloaded from server)
zip_path <- file.path(tempdir(), "MT_Lidar_Inventory.zip")
download.file("https://ftpgeoinfo.msl.mt.gov/Data/Spatial/MSDI/Elevation/Lidar/MT_Lidar_Inventory_Shapefile__04152025.zip",
              destfile = zip_path, mode = "wb")
#unzip quads
unzipped_files <- unzip(zip_path, exdir = tempdir())
shp_file <- unzipped_files[grepl("Lidar_quads\\.shp$", unzipped_files)]

#as as spatial object
quads <- st_read(shp_file)
head(quads)
names(quads)
crs(quads)

#filter to downloadables:
quads <- quads[quads$Downloadab == "Yes", ]
head(quads)

#transform to crs of quads
bbox <- st_transform(bbox, crs(quads))
crs(bbox)

#get list of every quad the bbox overlaps with
quads_bbox <- st_intersection(quads, bbox)
quads_to_download <- quads_bbox %>% pull (QCode_Text)
length(quads_to_download)

#set location to download to, an external drive is suggested! and create the output location
output <- "./lidar/"
if (!dir.exists(output)) dir.create(output, recursive = TRUE)

#for each quad that overlaps with bbox, check if its been downloaded to the output, then try to download
for (quad in quads_to_download) {
  zip_name <- paste0(quad, ".zip")
  zip_path <- file.path(output, zip_name)
  url <- paste0("https://ftpgeoinfo.msl.mt.gov/Data/Spatial/MSDI/Elevation/Lidar/Quads/", zip_name)
  
  if (!file.exists(zip_path)) {
    message("Downloading: ", quad)
    tryCatch({
      download.file(url, destfile = zip_path, mode = "wb", method='curl')
    }, error = function(e) {
      message("Failed to download ", quad, ": ", e$message)
    })
  } else {
    message("Already exists: ", quad)
  }
}

#next unzip all files to new unzipped directory.
output_unzipped <- "./lidar_unzipped/"
if (!dir.exists(output_unzipped)) dir.create(output_unzipped, recursive = TRUE)
downloaded_dir <- list.files(output,full.names = TRUE)
for(zipped in downloaded_dir){
  print(paste0('Attempting to unzip: ',zipped))
  base_name <- basename(zipped)
  dest_folder <- file.path(output_unzipped,sub("\\.zip$|\\.tar.gz$", "", base_name, ignore.case = TRUE))
  if (!dir.exists(dest_folder)) dir.create(dest_folder, recursive = TRUE)
  unzip(zipped, exdir = dest_folder)
  print(paste0('Finished unzipping: ',zipped))
}

#find all files for the selected dsm, chm, dtm type
chm_files <- list.files(
  path = output_unzipped,          
  pattern = "chm.*\\.tif$",
  recursive = TRUE, 
  full.names = TRUE,
  ignore.case = TRUE
)

dsm_files <- list.files(
  path = output_unzipped,          
  pattern = "dsm.*\\.tif$",
  recursive = TRUE, 
  full.names = TRUE,
  ignore.case = TRUE
)

dem_files <- list.files(
  path = output_unzipped,          
  pattern = "hfdem.*\\.tif$",
  recursive = TRUE, 
  full.names = TRUE,
  ignore.case = TRUE
)

#decide if you will aggregate files to coarser scale
#basically iterate through each raster and aggregate before resampling.

#need to resample, overwrite the rasters in differnt crs
#chm
ref_rast <- rast(chm_files[1])
raster_template <- rast(ext = ext(bbox), resolution = 1, crs = crs(ref_rast))
bbox_rast <- rasterize(bbox,raster_template)
for (i in seq_along(chm_files)) {
  print(chm_files[i])
  r_i <- rast(chm_files[i])
  if (!identical(crs(r_i), crs(ref_rast))) {
    message("CRS differs, reprojecting...")
    r_i <- project(r_i, crs)
  }
  r_i <- resample(r_i,bbox_rast)
  writeRaster(r_i, paste0(chm_files[i]), overwrite = TRUE)
}
#mosaic together
r_list <- lapply(chm_files, rast)
sprc <- sprc(r_list)
chm <- merge(sprc)
writeRaster(chm,"chm.tif",overwrite=TRUE)
rm(sprc)
rm(chm)
#============
#dem
ref_rast <- rast(dem_files[1])
for (i in seq_along(dem_files)) {
  print(dem_files[i])
  r_i <- rast(dem_files[i])
  if (!identical(crs(r_i), crs(ref_rast))) {
    message("CRS differs, reprojecting...")
    r_i <- project(r_i, crs)
  }
  r_i <- resample(r_i,bbox_rast)
  writeRaster(r_i, paste0(dem_files[i]), overwrite = TRUE)
}
#mosaic together
r_list <- lapply(dem_files, rast)
sprc <- sprc(r_list)
dem <- merge(sprc)
writeRaster(dem,"dem.tif",overwrite=TRUE)
rm(sprc)
rm(dem)
#==========
#dsm
ref_rast <- rast(dsm_files[1])
for (i in seq_along(dsm_files)) {
  print(dsm_files[i])
  r_i <- rast(dsm_files[i])
  if (!identical(crs(r_i), crs(ref_rast))) {
    message("CRS differs, reprojecting...")
    r_i <- project(r_i, crs)
  }
  r_i <- resample(r_i,bbox_rast)
  writeRaster(r_i, paste0(dsm_files[i]), overwrite = TRUE)
}
#mosaic together
r_list <- lapply(dsm_files, rast)
sprc <- sprc(r_list)
dsm <- mosaic(sprc)
writeRaster(dsm,"dsm.tif",overwrite=TRUE)
rm(sprc)
rm(dsm)

#Just like that you have a mosaiced 1m LIDAR derived chm, dsm, or dem.
