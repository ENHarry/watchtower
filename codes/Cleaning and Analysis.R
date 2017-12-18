cleanWatchTower <- function(x){
  library(data.table)
  library(plyr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(sqldf)
  library(lubridate)
  
  # read in the first data set
  data <- fread("watchtower_NBCPCONRAPIWT_10.17.101.126%253A8091.csv", select = c("id", "value"))
  
  # separate watching data from favourites
  watching <- sqldf("select * from data where value LIKE '%percentViewed%'")
  favourites <- sqldf("select * from data where value LIKE '%favoriteType%'")
  
  watchtran <- as.data.frame(watching[,1])
  favtran <- as.data.frame(favourites[,1])
  setnames(watchtran, c("watching[, 1]"), c("transactionId"))
  setnames(favtran, c("favourites[, 1]"), c("transactionId"))       
  
  fav <- as.data.frame(favourites[, -1])
  watch <- as.data.frame(watching[, -1])
  
  # remove the original data
  rm(data)
  
  # remove all special characters from the favourites data
  
  fav[] <- lapply(fav, gsub, pattern= 'customFields"":', replacement='')
  fav[] <- lapply(fav, gsub, pattern= '"', replacement='')
  fav[] <- lapply(fav, gsub, pattern= '[{}]', replacement='')
  fav[] <- lapply(fav, gsub, pattern= ',', replacement=', ')
  fav[] <- lapply(fav, gsub, pattern= ':', replacement=': ')
  
  setnames(fav, c("favourites[, -1]"), c("V1"))
  
  # separate the column in to multiple columns of different fields
  
  newfav <- fav %>% 
    separate(V1, c("showId", "deleted", "favoriteType", "device",
                      "brandId", "createdTimestamp", "class", "type", "userId",
                      "updatedTimestamp"), ",") %>% 
    select(showId, deleted, brandId, createdTimestamp, type, userId,
           updatedTimestamp)
  
  newfav[] <- lapply(newfav, gsub, pattern= ".*:", replacement='')
  newfav$unixtimeCreated <- newfav$createdTimestamp
  newfav$unixtimeUpdated <- newfav$updatedTimestamp
  newfav <- cbind(favtran, newfav)
  
  # convert the time and date from UNIX millisecond format to real time
  options(digits.secs = 6)
  newfav$createdTimestamp <- as.POSIXct(as.numeric(as.character(newfav$createdTimestamp))
                                        /1000,origin="1970-01-01", tz = "UTC")
  newfav$updatedTimestamp <- as.POSIXct(as.numeric(as.character(newfav$updatedTimestamp))
                                        /1000,origin="1970-01-01", tz = "UTC")
  
  # separate the date and time into individual columns 
  newfav <- newfav %>% 
    separate(createdTimestamp, c("dateCreated", "timeCreated"), " ") %>% 
    separate(updatedTimestamp, c("dateUpdated", "timeUpdated"), " ")  
  
  #Separating the milliseconds into an individual column
  newfav[] <- lapply(newfav, gsub, pattern= "[.]", replacement=',')
  newfav <- newfav %>%    
    separate(timeCreated, c("time.Created", "millisecsCreated"), "," ) %>% 
    separate(timeUpdated, c("time.Updated", "millisecsUpdated"), "," )
  
  rm(fav,favtran,favourites, watching)
  
  # remove all special characters from the watching data
  watch[] <- lapply(watch, gsub, pattern= '[{}]', replacement='')
  watch[] <- lapply(watch, gsub, pattern= '"', replacement='')
  watch[] <- lapply(watch, gsub, pattern= ':', replacement=': ')
  watch[] <- lapply(watch, gsub, pattern= ',', replacement=', ')
  
# separate the column in to multiple columns of different fields
  setnames(watch, c("watching[, -1]"), c("V1"))
  newwatch <- watch %>% 
    separate(V1, c("continueWatchingList", "watchDuration", "showName", 
                      "seasonNumber", "device", "platform", "createdTimestamp", 
                      "videoId", "type", "userId", "updatedTimestamp", "showId", 
                      "deleted", "brandId", "percentViewed", "class", "mpxGUID", 
                      "dateTimeWatched"), ",") %>% 
    select(userId, showId, showName, brandId, mpxGUID, percentViewed, seasonNumber,
           watchDuration, deleted, createdTimestamp, updatedTimestamp, dateTimeWatched,
           type, continueWatchingList)
  
  newwatch[] <- lapply(newwatch, gsub, pattern= ".*:", replacement='')
  
  newwatch <- cbind(watchtran, newwatch)
  
  rm(watch, watchtran)
  
  # convert the time and date from UNIX millisecond format to real time
  options(digits.secs = 6)
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
  
  #Separating the milliseconds into an individual column
  newwatch[] <- lapply(newwatch, gsub, pattern= "[.]", replacement=',')
  newwatch <- newwatch %>%    
    separate(timeCreated, c("time.Created", "millisecsCreated"), "," ) %>% 
    separate(timeUpdated, c("time.Updated", "millisecsUpdated"), "," ) %>% 
    separate(timeWatched, c("time.Watched", "millisecsWatched"), "," )
  
  newfav1 <- newfav
  newwatch1 <- newwatch
  
  output <- list()
  output$newfav <- newfav
  output$newwatch <- newwatch
  
  return(output)
  
}

cl$percentViewed <- lapply(cl$percentViewed, gsub, pattern= ",", replacement='.')

df2 <- compare_mutate(newwatch, newfav)
df3 <- compare_mutate(newwatch1, newfav1)

cl <- rbind(df, df2)
cl <- rbind(cl, df3)
cl <- cl[complete.cases(cl), ]

# count of brands per user
bT_ormore <- cl %>% 
  select(userId, brandId, dateWatched, time.Watched, percentViewed) %>% 
  group_by(userId) %>% 
  distinct() %>% 
  mutate(brand_count = n_distinct(brandId)) %>% 
  arrange(userId)

# remove years that don't correspond with 2017 and 2016
not2017 <- bT_ormore %>%
  mutate(years = year(as.Date(dateWatched))) %>% 
  filter(!(years <= 2017 & years >= 2016))
bT_ormore <-
ts <- not2017[,-7]
is2017 <- anti_join(bT_ormore, ts)
oneBrand <- Tu_ormore %>% 
  filter(brand_count==1)
twoBrands <- Tu_ormore %>% 
  filter(brand_count==2)
threeBrands <- Tu_ormore %>% 
  filter(brand_count==3)

# count the number of shows per user
sT_ormore <- cl %>% 
  select(userId, showName, dateWatched, time.Watched, percentViewed) %>% 
  group_by(userId) %>% 
  distinct() %>% 
  mutate(show_count = n_distinct(showName)) %>% 
  arrange(userId) 

# remove years that don't correspond with 2017 and 2016
not2017 <- sT_ormore %>%
  mutate(years = year(as.Date(dateWatched))) %>% 
  filter(!(years <= 2017 & years >= 2016))

ts <- not2017[,-7]
is2017 <- anti_join(sT_ormore, ts)
oneShow <- S_ormore %>% 
  filter(show_count==1)
twoShows <- S_ormore %>% 
  filter(show_count==2)
threeShows <- S_ormore %>% 
  filter(show_count==3)

# create structured data frame of users and their shows
twoShows <- twoShows %>% 
  group_by(userId) %>% 
  mutate(what = c("show1", "show2"))
threeShows <- threeShows %>% 
  group_by(userId) %>% 
  mutate(what = c("show1", "show2", "show3"))
expeu <- twoShows %>% 
  spread(what, showName)
tu_tally <- expeu %>% 
  group_by(show1, show2) %>% 
  tally()
expeu2 <- threeShows %>% 
  spread(what, showName)
tre_tally <- expeu2 %>% 
  group_by(show1, show2, show3) %>% 
  tally() %>% 
  arrange(n)

# create structured data frame of users and their brands
tworand <- twoBrands %>% 
  group_by(userId) %>% 
  mutate(what = c("brand1", "brand2"))
threerand <- threeBrands %>% 
  group_by(userId) %>% 
  mutate(what = c("brand1", "brand2", "brand3"))
expeu <- tworand %>% 
  spread(what, brandId)
tu_tally <- expeu %>% 
  group_by(brand1, brand2) %>% 
  tally()
tu_abv20 <- tu_tally %>% 
  filter(n>=20)
expeu2 <- threerand %>% 
  spread(what, brandId)
tre_tally <- expeu2 %>% 
  group_by(brand1, brand2, brand3) %>% 
  tally() %>% 
  arrange(n)
tre_abv20 <- tre_tally %>% 
  filter(n>=20)

suw <- data.frame(t(apply(tre_tally, 1, sort)))
weee <- data.frame(matrix(0, nrow = 277, ncol = 4))
weee$X1 <- as.character(suw$X2)
weee$X2 <- as.character(suw$X3)
weee$X3 <- as.character(suw$X4)
weee$X4 <- as.character(suw$X1)

we2 <- data.frame(matrix(0, nrow = 4, ncol = 4))
we2$X1 <- as.character((weee[274:277, 4]))
we2$X2 <- as.character((weee[274:277, 1]))
we2$X3 <- as.character((weee[274:277, 2]))
we2$X4 <- as.character((weee[274:277, 3]))

weee[274:277, 1] <- we2[1:4, 1]
weee[274:277, 2] <- we2[1:4, 2]
weee[274:277, 3] <- we2[1:4, 3]
weee[274:277, 4] <- we2[1:4, 4]

suw <- weee %>% 
  group_by(X1, X2, X3) %>% 
  summarise(No_Users = sum(as.numeric(X4))) %>% 
  unite(brands, X1, X2, X3, sep = ",") %>% 
  filter(No_Users > 100)
write.csv(suw, "tri_brand.csv")

no <- suw %>% 
  ungroup() %>% 
  mutate(norm_users = round((No_Users - min(No_Users))/(max(No_Users)-min(No_Users)), 3))
write.csv(no, "tri.csv")

# Users with 2 brands
suw <- data.frame(t(apply(tu_tally, 1, sort)))
weee <- data.frame(matrix(0, nrow = 76, ncol = 3))
weee$X1 <- as.character(suw$X2)
weee$X2 <- as.character(suw$X3)
weee$X3 <- as.character(suw$X1)

we2 <- data.frame(matrix(0, nrow = 3, ncol = 3))
we2$X1 <- as.character((weee[c(1, 8, 9), 3]))
we2$X2 <- as.character((weee[c(1, 8, 9), 1]))
we2$X3 <- as.character((weee[c(1, 8, 9), 2]))

weee[c(1, 8, 9), 1] <- we2[1:3, 1]
weee[c(1, 8, 9), 2] <- we2[1:3, 2]
weee[c(1, 8, 9), 3] <- we2[1:3, 3]

suw <- weee %>% 
  filter(X1 != "esquire" | X2 != "esquire") %>% 
  group_by(X1, X2) %>% 
  summarise(No_Users = sum(as.numeric(X3))) %>% 
  filter(No_Users > 120)
setnames(suw, c("X1", "X2"), c("Brand1", "Brand2"))
write.csv(suw, "tu_brand.csv")

no <- suw %>% 
  ungroup() %>% 
  mutate(norm_users = (No_Users - min(No_Users))/(max(No_Users)-min(No_Users))) %>% 
  unite(Brands, Brand1, Brand2, sep = ",")
write.csv(no, "tu.csv")

# filter out the years that dont match 2016 and 2017
clWT <- cl %>% 
  mutate(years = year(as.Date(dateWatched))) %>% 
  filter(years >= 2016  & years <= 2017) %>%
  select(-years) %>% 
  distinct()

# merge the data with counts of shows and brands per user
sb <- merge(bT_ormore, sT_ormore, by = c("userId", "dateWatched", "time.Watched"))
sb <- unique(sb[, -c(2,3,5,8)])

# function to check the most frequent entry in a given field
Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# duplicate records with different transaction id
dup <- clWT[,-1]
duplicates <- clWT[duplicated(dup),]

# count the number of entries per user
topusers <- clWT %>% 
  select(userId, brandId, showName, mpxGUID, dateWatched, time.Watched, percentViewed) %>% 
  group_by(userId) %>% 
  distinct() %>% 
  ungroup(userId) %>% 
  add_count(userId)

# since add_count gives the new column the name "n", change the name
setnames(topusers, c("n"), c("record_count"))

# count the number of videos viewed per user and chang the column name as well
user_rank <- topusers %>% 
  select(userId, brandId, showName, dateWatched, time.Watched, mpxGUID, 
         percentViewed, record_count) %>% 
  group_by(userId, showName) %>% 
  mutate(videos_per_show = n_distinct(mpxGUID)) 
setnames(user_rank, c("n"), c("videos_per_show"))

# chang the datewatched to specific weekdays and the time to specific hour in 
user_rank$dateWatched <- weekdays(as.Date(user_rank$dateWatched))
user_rank$time.Watched <- hour(as.POSIXct(user_rank$time.Watched, format = "%T", 
                                          origin="1970-01-01"))

' 
find the most frequent day, time, average videos per show  and average percentviewed,
by each user for each show they have watched.
'
user_analysis <- user_rank %>% 
  select(-mpxGUID) %>% 
  mutate(freq_day = Mode(dateWatched), freq_hour = Mode(time.Watched)) %>% 
  select(-dateWatched, -time.Watched) %>% 
  mutate(avg_viewcount = mean(videos_per_show), 
         avg_percentviewed = mean(percentViewed)) %>%
  select(-percentViewed)
user_analysis <- unique(user_analysis)

userstats <- merge(user_analysis, sb, by= c("userId", "brandId", "showName"))
userstats <- unique(userstats)

user_analysis_brand <- user_rank %>% 
  select(-mpxGUID) %>% 
  ungroup() %>% 
  group_by(userId) %>% 
  mutate(freq_day = Mode(dateWatched), freq_hour = Mode(time.Watched)) %>% 
  ungroup() %>% 
  group_by(userId, showName) %>% 
  select(-dateWatched, -time.Watched) %>% 
  mutate(avg_viewcount = mean(videos_per_show), 
         avg_percentviewed = mean(percentViewed)) %>%
  select(-percentViewed) %>% 
  ungroup() %>%
  distinct()

summary_analysis <- userstats %>% 
  select(-showName) %>% 
  group_by(userId) %>% 
  summarise(no_shows = Mode(show_count), view_percent = Mode(avg_percentviewed),
            viewcount = Mode(avg_viewcount), records =  Mode(record_count), 
            no_brands = Mode(brand_count),time = median(freq_hour), day = Mode(freq_day))

# final data
newdata <- clWT[, -c(1,3,7:15,18:25)]
newdata <- unique(newdata)
data <- merge(newdata, userstats, by= c("userId", "brandId", "showName"))
data <- unique(data)

# remove esquire from the data set.
esquire <-  %>%
  filter(str_detect(brandId, "esquire"))
final <- anti_join(wt, esquire)
nstst <- setorder(stst,-show_count, -avg_percentviewed, -record_count, -brand_count, 
                  -avg_viewcount)

# filter out any duplicates
wt <-unique(wt)

# export the final data as a csv for visualization in Tableau   
write.csv(wt,"WT.csv")
