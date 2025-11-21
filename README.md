## Download LIDAR derived Canopy Height, Digital Surface, and Bare Earth Models from [Montana Spatial Data Infrastructure (MSDI)](https://msl.mt.gov/geoinfo/data/msdi/)

![](./Picture2.png)
_Example data to download, images are examples around Bozeman, MT._

Function: A user inputs a .shp file of their study area, the script automates the downloading, resampling, reprojecting, and mosaicing of all available data within the study area bounding box to generate a DEM, DSM, and CHM. <br>
**NOTE: I suggest avoiding bounding boxes larger than 50km by 50km or you may run out of RAM.**<br>
_(Benchmarked ~60gb of RAM used at once for 50x50.)_
