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

## Model Specification to Explicit Dynamics
sir |> mp_print_during()

sir |> mp_expand() |> mp_print_during()

## Runge Kutta 4 ODE solver
sir |> mp_rk4() |> mp_expand() |> mp_print_during()

## Euler-multinational distribution (model with process error)
sir |> mp_euler_multinomial() |> mp_expand() |> mp_print_during()

## Manually construct an SEIR
seir = mp_tmb_model_spec(
      before = S ~ N - I - E - R    # Initial state
    , during = list(                # List is not used in SIR case
        mp_per_capita_flow(
          from     = "S"            # compartment from which individuals flow
        , to       = "E"            # compartment to which individuals flow
        , rate     = "beta * I / N" # expression giving per-capita flow rate
        , abs_rate = "exposure"     # name of absolute flow rate = beta * I * S/N
        )
      , mp_per_capita_flow(
          from     = "E"
        , to       = "I"
        , rate     = "alpha"
        , abs_rate = "infection"
      )
      , mp_per_capita_flow(
          from     = "I"
        , to       = "R"
        , rate     = "gamma"
        , abs_rate = "recovery"
      )
    )
  , default = list(  N = 100
                   , I = 1
                   , E = 0
                   , R = 0
                   , beta = 0.25
                   , alpha = 0.5
                   , gamma = 0.1
                   )
)
layout <- mp_layout_paths(seir)
plot_flow_diagram(layout,show_flow_rates = TRUE)

seir |> mp_expand() |> mp_print_during()

## Modifying models
# dir.create(file.path(getwd(),"macpan-workshop-library"), showWarnings =  F)

## Create a library with a template model from SIR
### library directory 
my_lib_dir = file.path(getwd(), "macpan-workshop-library")
### Name template directory
my_seir_dir = file.path(my_lib_dir,"seir")
my_si_dir = file.path(my_lib_dir,"si")

### Create temporary template based on existing library model
mp_model_starter("si", my_si_dir)
mp_model_starter("seir", my_seir_dir)

### Should start from sir for exercise

### Calling the models from library directory
my_seir = mp_tmb_library(my_seir_dir)
my_seir |> mp_expand() |> mp_print_during()

my_si = mp_tmb_library(my_si_dir)
my_si |> mp_expand() |> mp_print_during()

### Using updating method
new_si <- mp_tmb_update(my_si
              , phase="during",
              , at = 1,
              , expressions = list(
                mp_per_capita_flow(  from = "S"
                                   , to = "I"
                                   , rate = "beta * I * (S/N)^zeta"
                                   , abs_rate = "infection"
                                   )
              )
              , default = list (zeta = 1)
              )
new_si |> mp_expand() |> mp_print_during()
