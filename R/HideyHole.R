#####HideyHole - look for small holes in a digital elevation model raster

#' HideyHole - Look for small holes in a digital elevation model raster
#' @param r terra::rast object, a dtm grid
#' @param neighbourhood diamter in grid pixels for searching for holes
#' @param hole.depth depth in elevation units (typically m) to define local holes / depressions (default 21)
#' @param min.pixels minimum size of hole (in number of pixels), (default 100)
#' @param max.pixels maximum size of hole (in number of pixels), default NA = no maximum
#' @details HideyHole() find local depressions or holes in a digital elevation model that could be hiding spaces for organisms
#' such as fish or crustaceans. Achieved by comparing pixel heights with local averages, withs holes defined as clusters of pixels 
#' deeper than the local average by a given measure.
#' @return a list of the following elements
#'    HideyHoleCount: Number of distinct holes found
#'    HideyHoleCoverage: Proportion (0-1) of grid covered by hidey holes (2D area of holes / 2d area of grid)
#'    HideyHoleVector: SpatVector polygon object of each hole with attributes of area, pixels & deepest point (difference from local average)
#'    HideyHoleRaster: SpatRaster object a binary raster grid with 1=hidey hole, NA otherwise
#'    neighbourhood: Input parameter value
#'    hole.depth: Input parameter value
#'    min.pixels: Input parameter value
#'    max.pixels: Input parameter value
#' @examples
#' set.seed<-1
#' TestGrid<-terra::rast(matrix(runif(100), nrow=10, ncol=10))
#' terra::crs(TestGrid)<-"epsg:27700"
#' HideyHole(TestGrid, neighbourhood=5)
#' @export

HideyHole <- function(r, neighbourhood=21, hole.depth=0.1,
                      min.pixels=1, max.pixels=NA){
                      #,default.crs='epsg:4326'){

    # default maximum hole size is the size of the neighbourhood used in the analysis
    ## if(is.na(max.pixels)){
    ##     max.pixels<-neighbourhood^2
    ## }

    # calculate average depth over neighbourhood window
    r.av<-terra::focal(r, w=neighbourhood, fun=mean, na.rm=T)

    # find difference from local mean
    r.df<-r.av-r

    # find all pixels with hole-depth difference from local average
    r.hh<- r.df >= hole.depth

    # convert non-hole pixels to NAs
    terra::NAflag(r.hh)<-FALSE

    # create polygon to group together adjacent pixels
    p<-terra::as.polygons(r.hh, dissolve=T)

    # buffer negligably to ensure diagonally adjacent pixels overlap
    p2<-terra::buffer(p, width=terra::res(r)[1]/1000)

    # merge spatially overlapping polygons
    p3<-terra::aggregate(p2, dissolve=T)

    # seperate by spatially distinct regions
    p4<-terra::disagg(p3)

    # calculate area & perimeter for each polygon
    p4$area <- terra::expanse(p4, transform=F)
    p4$perimeter <- terra::perim(p4)
    p4$width <- terra::width(p4)

    # caculate circuference and diamter of circle the same area as the given polygon
    p4$circumferenceC <- 2*((pi*p4$area)^0.5)
    p4$diameterC <- (p4$area / pi)^0.5

    # create metric defining perimeter complexity as ratio of observed perimeter with minimal (circle) perimeter of the same area
    p4$perimeterComplexity <- p4$perimeter / p4$circumferenceC

    # create metric of thinness / thickness of polygon relative to circle of the same area
    p4$thinness <- p4$width / p4$diameterC

    # convert to pixels
    p4$pixels<-round(p4$area/(terra::res(r)[1]*terra::res(r)[2]),0)

    # filter by area
    p4$hideyhole <- (p4$pixels > min.pixels)

    # filter just hideyholes that are within the size range
    if(!is.na(max.pixels)){
        p5 <- p4[p4$hideyhole==T & p4$pixels <= max.pixels,]
    } else {
        p5 <- p4[p4$hideyhole==T,]
    }

    # fetch depth of hideyhole
    p5$relative.depth <- terra::extract(r.df, p5, fun=max)[,2]
    p5$grid.height <- terra::extract(r, p5, fun=min)[,2]

    # tell us how many pixels
    print(paste("found", sum(p5$hideyhole==T), "hideyholes"))

    # filter and return just hidey hole areas
    return(list(HideyHoleCount=sum(p5$hideyhole==T),
                HideyHoleCoverage=sum(p5$pixels)/terra::ncell(r),
                HideyHoleVector=p5,
                HideyHoleRaster=r.hh,
                neighbourhood=neighbourhood,
                hole.depth=hole.depth,
                min.pixels=min.pixels,
                max.pixels=max.pixels))
}

