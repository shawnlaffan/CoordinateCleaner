#' Identify Records Assigned to GBIF Headquarters
#' 
#' Removes or flags records within 0.5 degree radius around the GBIF headquarters in
#' Copenhagen, DK.
#' 
#' Not recommended if working with records from Denmark or the Copenhagen area.
#' 
#' @param buffer numerical. The buffer around the GBIF headquarters,
#' where records should be flagged as problematic. Units depend on geod. Default = 100 m.
#' @param geod logical. If TRUE the radius is calculated
#' based on a sphere, buffer is in meters. If FALSE
#' the radius is calculated in degrees. Default = T.
#' @inheritParams cc_cap
#' 
#' @inherit cc_cap return
#' 
#' @note See \url{https://ropensci.github.io/CoordinateCleaner} for more
#' details and tutorials.
#' 
#' @keywords Coordinate cleaning
#' @family Coordinates
#' 
#' @examples
#' 
#' x <- data.frame(species = "A", 
#'                 decimallongitude = c(12.58, 12.58), 
#'                 decimallatitude = c(55.67, 30.00))
#'                 
#' cc_gbif(x)
#' cc_gbif(x, value = "flagged")
#' 
#' @export
#' @importFrom geosphere destPoint
#' @importFrom sp coordinates CRS disaggregate over Polygon Polygons SpatialPolygons SpatialPoints
#' @importFrom rgeos gBuffer
cc_gbif <- function(x, 
                    lon = "decimallongitude", 
                    lat = "decimallatitude",
                    species = "species",
                    buffer = 1000,
                    geod = TRUE,
                    verify = FALSE,
                    value = "clean",
                    verbose = TRUE) {

  # check function argument validity
  match.arg(value, choices = c("clean", "flagged"))
  
  if (verbose) {
    message("Testing GBIF headquarters, flagging records around Copenhagen")
  }
  
  
  if(buffer > 10 & !geod){
    warnings("Using large buffer check 'geod'")
  }
  if(buffer < 100 & geod){
    warnings("Using small buffer check 'geod'")
  }
  
  # set default projection
  wgs84 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

  dat <- sp::SpatialPoints(x[, c(lon, lat)], 
                           proj4string = sp::CRS(wgs84))

  if(geod){
    # credits to https://seethedatablog.wordpress.com
    dg <- seq(from = 0, to = 360, by = 5)
    
    buff_XY <- geosphere::destPoint(p = cbind(12.58, 55.67), 
                                    b = rep(dg, each = 1), 
                                    d = buffer)
    
    id <- rep(1, times = length(dg))
    
    
    lst <- split(data.frame(buff_XY), f = id)
    
    # Make SpatialPolygons out of the list of coordinates
    poly   <- lapply(lst, sp::Polygon, hole = FALSE)
    polys  <- lapply(list(poly), sp::Polygons, ID = NA)
    ref <- sp::SpatialPolygons(Srl = polys, proj4string = CRS(wgs84))
    
    #point in polygon test
    out <- is.na(sp::over(x = dat, y = ref))
  }else{
    ref <- rgeos::gBuffer(sp::SpatialPoints(cbind(12.58, 55.67), 
                                            proj4string = sp::CRS(wgs84)), 
                          width = 0.5)
    
    out <- sp::over(x = dat, y = ref)
    out <- is.na(out)
  }
  
  # implement the verification
  if(verify & sum(out) > 0){
    # get flagged coordinates
    ver <- x[!out,]
    
    #count the instances of all flagged records
    ver_count <- aggregate(ver[[species]] ~ ver[[lon]] + 
                            ver[[lat]] , FUN = "length")
    names(ver_count) <- c(lon, lat, "coord.count")
    
    ver_spec <- aggregate(ver[[lon]] ~ ver[[species]], FUN = "length")
    names(ver_spec) <- c(species, "species.count")

    #test which flagged x occur multiple times
    tester <- data.frame(x, ord = seq_len(nrow(x)))
    tester <- merge(tester, ver_count, by = c(lon,lat), all = TRUE)
    tester <- merge(tester, ver_spec, by = species, all = TRUE)
    
    tester <- tester[order(tester$ord),]
    tester[is.na(tester)] <- 0
    
    #only flag those records that occure with only one coordinate in the buffer
    out <-  tester$coord.count <= tester$species.count| out
  }
  
  if (verbose) {
    if(value == "clean"){
      message(sprintf("Removed %s records.", sum(!out)))
    }else{
      message(sprintf("Flagged %s records.", sum(!out)))
    }
  }

  switch(value, clean = return(x[out, ]), flagged = return(out))
}
