compare_mutate <- function(x,y){
  library(sqldf)
  library(dplyr)
  x <- x[, -c(10,19,20, 21)]
  y <- y[, -c(3,8)]
  setnames(y, c("dateCreated", "time.Created", "millisecsCreated", 
                "dateUpdated", "time.Updated", "millisecsUpdated",
                "unixtimeCreated","unixtimeUpdated"), 
           c("F.dateCreated", "F.time.Created", "F.millisecsCreated",            
             "F.dateUpdated", "F.time.Updated", "F.millisecsUpdated",
             "F.unixtimeCreated","F.unixtimeUpdated"))
  nudf <- sqldf("select * from x 
                join y on x.showId == y.showId
                and x.userId == y.userId")
  nudf <- nudf[, -c(18,19,20,24)]
  nedf <- anti_join(x, nudf)
  nudf <- nudf %>%
    mutate(favorites = 1)
  nedf <- nedf %>%
    mutate(F.dateCreated = 0, F.time.Created = 0, F.millisecsCreated = 0,            
           F.dateUpdated = 0, F.time.Updated = 0, F.millisecsUpdated = 0,
           F.unixtimeCreated = 0 ,F.unixtimeUpdated = 0, favorites = 0)
  df <- rbind(nudf, nedf)
  df <- df %>%
    arrange(userId)
  return(df)
}