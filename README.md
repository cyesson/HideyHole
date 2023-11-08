# HideyHole

Code to find small holes in a digital elevation model raster

Example
```r
# load your terra raster grid
r<-terra::rast("myfile.tif")
# run the hole finder with the default parameters
h<-HideyHole(r)
# plot the original grid
plot(r)
# overlay the holes we've found
plot(h$HideyHoleVector, add=T)
```
