#This code replicates SimulatedWorld_ROMS_function, but adds in a trophic interaction, where:
#Species A: distribution and abundance drivn by SST and Chl-a
#Species B: distribution and abundance drivn by SST and Species A
#EM for Species b: only have chl-a and temp as covariates. 
## Switch to Spring Averages 
## add in Sampling Bias to simulate fishery dependent data collection
#Note only using GFDL for now

#temporary: set directory for running an example online
#dir <- "~/DisMAP project/Location, Location, Location/Location Workshop/ROMS"

SimulateWorld_ROMS_TrophicInteraction_SB <- function(dir){
  library(virtualspecies)
  library(scales)
  library(raster)
  library(glmmfields)
  library(rgeos)
  
  #----IMPORTANT----
  #Download spring averages ROMS data from here: https://www.dropbox.com/sh/pj1vjz4h1n27hnb/AAD9sySDudMKmq3l4yLPvjQra?dl=0
    
  # #----Create output file----
  #####Needs to be modified as variables are added. Starting with sst
  #Assuming 100 'samples' are taken each year, from 1980-2100
  output <- as.data.frame(matrix(NA, nrow=12100,ncol=7))
  colnames(output) <- c("lon","lat","year","pres","suitability","sst", "chla")
  
  #----Load in rasters----
  files_sst <- list.files(paste0(dir,'/sst_monthly'), full.names = TRUE, pattern=".grd") #should be 121 files
  files_chl <- list.files(paste0(dir,'/chl_surface'), full.names = TRUE, pattern=".grd") #should be 121 files
  years <- seq(1980,2100,1)
  
  #loop through each year
  for (y in 1:121){
    print(paste0("Creating environmental simulation for Year ",years[y]))
    
    sst <- raster(files_sst[y])
    chla <- raster(files_chl[y])
    chla <- log(chla)
    #plot(sst)
    #plot(chla)
    # 
    #----SPECIES A: assign response curve----
    #Species A: likes high chla and medium temps
    
    #Stack rasters
    spA_stack <- stack(sst, chla)
    names(spA_stack) <- c('sst', 'chla')
    #Assign preferences
    spA_parameters <- formatFunctions(sst = c(fun="dnorm",mean=12,sd=3),
                                      chla = c(fun="dnorm",mean=1.6,sd=9))
    spA_suitability <- generateSpFromFun(spA_stack,parameters=spA_parameters, rescale = FALSE,rescale.each.response = FALSE) #Important: make sure rescaling is false. Doesn't work well in the 'for' loop. 
    # plot(spA_suitability$suitab.raster) #plot habitat suitability
    # virtualspecies::plotResponse(spA_suitability) #plot response curves
    
    #manually rescale
    ref_max_sst <- dnorm(spA_parameters$sst$args[1], mean=spA_parameters$sst$args[1], sd=spA_parameters$sst$args[2]) #JS/BM: potential maximum suitability based on optimum temperature
    ref_max_chl <- dnorm(spA_parameters$chla$args[1], mean=spA_parameters$chla$args[1], sd=spA_parameters$chla$args[2]) 
    ref_max <- ref_max_sst * ref_max_chl #simple multiplication of layers. 
    spA_suitability$suitab.raster <- (1/ref_max)*spA_suitability$suitab.raster #JS/BM: rescaling suitability, so the max suitbaility is only when optimum is encountered
    # plot(spA_suitability$suitab.raster) #plot habitat suitability
    
    #----SPECIES B: assign response curve----
    #Species B: likes to eat Species A, and warmer temperatues
    
    #Stack rasters
    spB_stack <- stack(sst, spA_suitability$suitab.raster)
    names(spB_stack) <- c('sst', 'spA')
    
    #Assign preferences
    spB_parameters <- formatFunctions(sst = c(fun="dnorm",mean=15,sd=4),
                                      spA = c(fun="dnorm",mean=0.8,sd=1))
    spB_suitability <- generateSpFromFun(spB_stack,parameters=spB_parameters, rescale = FALSE,rescale.each.response = FALSE)
    # plot(spB_suitability$suitab.raster) #plot habitat suitability
    # virtualspecies::plotResponse(spB_suitability) #plot response curves
    # 
    #manually rescale
    ref_max_sst <- dnorm(spB_parameters$sst$args[1], mean=spB_parameters$sst$args[1], sd=spB_parameters$sst$args[2]) #JS/BM: potential maximum suitability based on optimum temperature
    ref_max_spA <- dnorm(spB_parameters$spA$args[1], mean=spB_parameters$spA$args[1], sd=spB_parameters$spA$args[2])
    ref_max <- ref_max_sst * ref_max_spA
    spB_suitability$suitab.raster <- (1/ref_max)*spB_suitability$suitab.raster #JS/BM: rescaling suitability, so the max suitbaility is only when optimum temp is encountered
    # plot(spB_suitability$suitab.raster) #plot habitat suitability
    # 
    #----Convert suitability to Presence-Absence----
    #JS: relaxes logistic a little bit, by specifing reduced prevalence and fitting beta (test diff prevalence values, but 0.5 seems realistic)
    suitability_PA <- virtualspecies::convertToPA(spB_suitability, PA.method = "probability", beta = "random",
                                                  alpha = -0.05, species.prevalence = 0.5, plot = FALSE)
    # plotSuitabilityToProba(suitability_PA) #Let's you plot the shape of conversion function
    # plot(suitability_PA$pa.raster)
    
    #-----Sample Presences and Absences-----
    
     #.....# 6 below is the best options to work with I think!!......##
    
    #1. These lines show the original sampling -- fish independend sampling w/ 100 points
    # presence.points<-sampleOccurrences(suitability_PA, n=100, type="presence-absence",
    # detection.probability = 1, plot = TRUE)
    # df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    # colnames(df) <- c("x","y")
    
    #2. sampling with uneven intensity. This simulates increased sampling in an area which 
        #we can change to be the actual footprint of the fishing grounds or maybe a raster based on 
        #that years suitability? To simulate the fishery following the fish? 
    #fishground<-extent(-128, -125, 33, 40)
    #presence.points<-sampleOccurrences(suitability_PA, n=400, type="presence-absence",
     #                                  bias="extent", bias.strength=50, bias.area=fishground)
    #df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    #colnames(df) <- c("x","y")
    
    #3.  Below is code to simulate sampling that is has probability of detection biased towards areas with high suitability (b/c)
      # assumes those areas will have higher abundnace so higher detection prob. This could simulate how the fishery targets the fish 
      #therefore seeks out areas where they know/think they will find a lot of them 
    
    # presence.points<-sampleOccurrences(suitability_PA, n=400, type="presence-absence",
    #                                   detection.probability = 0.8, correct.by.suitability = TRUE,plot = TRUE)
    # df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    # colnames(df) <- c("x","y")
    
    # 4. the below code will uses 'manual sampling bias' to bias sampling to be more likely in 
    # in areas of high suitability. Sampling intensity is weighted by suitability raster
    # presence.points<-sampleOccurrences(suitability_PA, n=400, type="presence-absence",
    #                                   detection.probability = 1, bias = "manual", weights = spB_suitability$suitab.raster, plot = TRUE)
    # df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    # colnames(df) <- c("x","y")
    
    # 5. same as above, but with less samples and precence only data
    # presence.points<-sampleOccurrences(suitability_PA, n=100, type="presence only",
    #                                    detection.probability = 1, bias = "manual", weights = spB_suitability$suitab.raster, plot = TRUE)
    # df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    # colnames(df) <- c("x","y")
    
    # 6. Convert Suitability_PA to a polygon of presence area, and bias sampling intensity to polygon of high suitability
    # also decreased sample size to more accurately mimic the amount of samples/data would get from trawl fishery on West Coast
    pres_poly<- rasterToPolygons(suitability_PA$pa.raster, function(x){x == 1}, dissolve = TRUE) 
        # plot(pres_poly)
    presence.points<-sampleOccurrences(suitability_PA, n=100, type="presence-absence",
                                       detection.probability = 1, bias = "polygon", bias.strength = 10, bias.area= pres_poly, plot = TRUE)
    df <- cbind(as.data.frame(round(presence.points$sample.points$x,1)),as.data.frame(round(presence.points$sample.points$y,1)))
    colnames(df) <- c("x","y")
    
    #----Extract data for each year----
    print("Extracting suitability")
    ei <- 100*y #end location in output grid to index to
    se <- ei - 99 #start location in output grid to index to
    output$lat[se:ei] <- df$y
    output$lon[se:ei] <- df$x
    output$year[se:ei] <- rep(years[y],100)
    output$pres[se:ei] <-  presence.points$sample.points$Real
    output$suitability[se:ei] <- raster::extract(spB_suitability$suitab.raster, y= df)  #extract points from suitability file
    output$sst[se:ei] <-  raster::extract(sst, y= df)  #extract points from suitability file
    output$chla[se:ei] <-  raster::extract(chla, y= df)
    
  }
  
  #----Create abundance as a function of the environment----
  # SB: values in Ecography paper. I think initially they were based on flounder in EBS but not sure if I edited them
  #parameters need to be updated
  output$abundance <- ifelse(output$pres==1,rlnorm(nrow(output),2,0.1)*output$suitability,0)
  return(output)
}

#----example-----
test <- SimulateWorld_ROMS_TrophicInteraction_SB(dir = dir)
