# Installation
# repos = c('https://canmod.r-universe.dev', 'https://cloud.r-project.org')
# install.packages('macpan2', repos = repos)

library(macpan2) ## obviously
library(ggplot2)
library(dplyr)
library(lubridate)

sessionInfo() |> print()
show_models()

sir <- mp_tmb_library("starter_models","sir", package = "macpan2")
sir |> print()

(sir
  |> mp_simulator(
    time_steps = 100
    ,outputs = c("I", "infection")
)
  |> mp_trajectory()
  |> mutate(quantity=case_match( matrix
                                 , "I" ~ "Prevalence"
                                 , "infection" ~ "Incidence"
                                 )
            )
  |> ggplot()
  + geom_line(aes(time,value))
  + facet_wrap(~ quantity,scales = "free")
  + theme_bw()
) |> print()
