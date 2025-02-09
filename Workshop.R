# Installation
# repos = c('https://canmod.r-universe.dev', 'https://cloud.r-project.org')
# install.packages('macpan2', repos = repos)

library(macpan2) ## obviously
library(ggplot2)
library(dplyr)
library(lubridate)

# sessionInfo() |> print()
# show_models()

sir <- mp_tmb_library("starter_models","sir", package = "macpan2")
sir |> print()

## Simulation and plot of SIR model
(sir
  # simulation
  |> mp_simulator(
    time_steps = 100
    ,outputs = c("I", "infection")
) 
  # formating data to long format for figure
  |> mp_trajectory()
  
  # Rename models
  |> mutate(quantity=case_match( matrix
                                 , "I" ~ "Prevalence"
                                 , "infection" ~ "Incidence"
                                 )
            )
  # plot with ggplot
  |> ggplot()
  + geom_line(aes(time,value))
  + facet_wrap(~ quantity,scales = "free")
  + theme_bw()
) |> print()

## create box diagrams from model
mp_print_during(sir)

## show the flow diagram
system.file("utils", "box-drawing.R", package = "macpan2") |> source()
layout <- mp_layout_paths(sir)
plot_flow_diagram(layout,show_flow_rates = TRUE)
