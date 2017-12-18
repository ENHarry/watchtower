cleanWatchTower <- function(x){
  library(data.table)
  library(plyr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(sqldf)
  
  # read in the first data set
  data <- fread(x, select = c("value"))
  
  # separate watching data from favourites
  watching <- sqldf("select * from data where value LIKE '%percentViewed%'")
  favourites <- sqldf("select * from data where value LIKE '%favoriteType%'")
  
  # remove the original data
  rm(data)
  
  # remove all special characters from the favourites data
  
  favourites[] <- lapply(favourites, gsub, pattern= 'customFields"":', replacement='')
  favourites[] <- lapply(favourites, gsub, pattern= '"', replacement='')
  favourites[] <- lapply(favourites, gsub, pattern= '[{}]', replacement='')
  favourites[] <- lapply(favourites, gsub, pattern= ',', replacement=', ')
  favourites[] <- lapply(favourites, gsub, pattern= ':', replacement=': ')
  
  # separate the column in to multiple columns of different fields
  
  newfav <- favourites %>% 
    separate(value, c("showId", "deleted", "favoriteType", "device",
                      "brandId", "createdTimestamp", "class", "type", "userId",
                      "updatedTimestamp"), ",") %>% 
    select(showId, deleted, brandId, createdTimestamp, type, userId,
           updatedTimestamp)
  
  newfav[] <- lapply(newfav, gsub, pattern= ".*:", replacement='')
  
  
  # remove all special characters from the watching data
  
  watching[] <- lapply(watching, gsub, pattern= 'customFields"":', replacement='')
  watching[] <- lapply(watching, gsub, pattern= '"', replacement='')
  watching[] <- lapply(watching, gsub, pattern= '[{}]', replacement='')
  watching[] <- lapply(watching, gsub, pattern= ',', replacement=', ')
  watching[] <- lapply(watching, gsub, pattern= ':', replacement=': ')
  
  # separate the column in to multiple columns of different fields
  
  newwatch <- watching %>% 
    separate(value, c("continueWatchingList", "watchDuration", "showName", 
                      "seasonNumber", "device", "platform", "createdTimestamp", 
                      "videoId", "type", "userId", "updatedTimestamp", "showId", 
                      "deleted", "brandId", "percentViewed", "class", "mpxGUID", 
                      "dateTimeWatched"), ",") %>% 
    select(userId, showId, showName, brandId, mpxGUID, percentViewed, seasonNumber,
           watchDuration, deleted, createdTimestamp, updatedTimestamp, dateTimeWatched,
           type, continueWatchingList)
  
  newwatch[] <- lapply(newwatch, gsub, pattern= ".*:", replacement='')
  
  # remove all na
  
  newwatch <- newwatch[complete.cases(newwatch), ]
  newfav <- newfav[complete.cases(newfav), ]
  
  # convert the time and date from UNIX millisecond format to real time
  
  newfav$createdTimestamp <- as.POSIXct(as.numeric(as.character(newfav$createdTimestamp))
                                        /1000,origin="1970-01-01", tz = "UTC")
  newfav$updatedTimestamp <- as.POSIXct(as.numeric(as.character(newfav$updatedTimestamp))
                                        /1000,origin="1970-01-01", tz = "UTC")
  
  
  newwatch$createdTimestamp <- as.POSIXct(as.numeric
                                          (as.character(newwatch$createdTimestamp))/1000,
                                          origin="1970-01-01", tz = "UTC")
  newwatch$updatedTimestamp <- as.POSIXct(as.numeric
                                          (as.character(newwatch$updatedTimestamp))/1000,
                                          origin="1970-01-01", tz = "UTC")
  newwatch$dateTimeWatched <- as.POSIXct(as.numeric
                                         (as.character(newwatch$dateTimeWatched))/1000,
                                         origin="1970-01-01", tz = "UTC")
  
  # separate the date and time into individual columns
  
  newwatch <- newwatch %>% 
    separate(createdTimestamp, c("dateCreated", "timeCreated"), " ") %>% 
    separate(updatedTimestamp, c("dateUpdated", "timeUpdated"), " ") %>% 
    separate(dateTimeWatched, c("dateWatched", "timeWatched"), " ") 
  
  newfav <- newfav %>% 
    separate(createdTimestamp, c("dateCreated", "timeCreated"), " ") %>% 
    separate(updatedTimestamp, c("dateUpdated", "timeUpdated"), " ") 
  
  # remove all na again
  
  newwatch <- newwatch[complete.cases(newwatch), ]
  newfav <- newfav[complete.cases(newfav), ]
  output <- list()
  output$newfav <- newfav
  output$newwatch <- newwatch
  
  return(output)
  
}