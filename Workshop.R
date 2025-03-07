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


# Compare Simulated and Observed Incidence
release = "https://github.com/canmod/macpan2/releases/download/macpan1.5_data"
covid_on = (release
            |> file.path("covid_on.RDS")
            |> url() 
            |> readRDS()
)
covid_on |> head() |> print()

covid_on |> summary()

reports = (covid_on
           |> filter(var == "report")
           ##|> filter(abs(value) < 10^4) ## do not believe numbers higher than 10^4
)

(reports
  |> ggplot()
  + geom_line(aes(date, value))
  + theme_bw()
)

sir_covid = mp_tmb_insert(sir
                          
                          ## Modify the the part of the model that
                          ## is executed once "during" each iteration
                          ## of the simulation loop.
                          , phase = "during"
                          
                          ## Insert the new expressions at the 
                          ## end of each iteration.
                          ## (Inf ~ infinity ~ end)
                          , at = Inf
                          
                          ## Specify the model for under-reporting as
                          ## a simple fraction of the number of new
                          ## cases every time-step.
                          , expressions = list(reports ~ report_prob * infection)
                          
                          ## Update defaults to something a little more 
                          ## reasonable for early covid in Ontario.
                          , default = list(
                              gamma = 1/14      ## 2-week recovery
                            , beta = 2.5/14     ## R0 = 2.5
                            , report_prob = 0.1 ## 10% of cases get reported
                            , N = 1.4e7         ## Ontario population  
                            , I = 50            ## start with undetected infections
                          )
)

sir_covid |> mp_expand() |> print()
sir |> mp_expand() |> print()

### simulating reports
early_reports = filter(reports, date < as.Date("2020-07-01"))
(early_reports
  |> ggplot()
  + geom_line(aes(date, value))
  + theme_bw()
)
sim_early_reports = (sir_covid 
                     |> mp_simulator(
                       time_steps = nrow(early_reports)
                       , outputs = "reports"
                     )
                     |> mp_trajectory()
                     |> mutate(
                       date = min(early_reports$date) + days(time)
                     )
)
comparison_early_reports = bind_rows(
  list(
    simulated = sim_early_reports
    , observed = early_reports
  )
  , .id = "source"
)
(comparison_early_reports
  |> ggplot()
  + geom_line(aes(date, value, colour = source))
  
  ## constrain y-axis to the range of the
  ## observed data, otherwise the simulations
  ## will make it impossible to see the data
  + coord_cartesian(ylim = c(0, max(early_reports$value, na.rm = TRUE)))
  + theme_bw() 
  + theme(legend.position="bottom")
)


# delay in reporting
si <- mp_tmb_library("starter_models","si", package = "macpan2")
si_with_delays = (si
                  |> mp_tmb_insert_reports(
                    incidence_name = "infection"
                    , mean_delay = 50
                    , cv_delay = 0.25
                    , report_prob = 1
                    , reports_name = "reports"
                  )
)
(si_with_delays
  |> mp_simulator(
    time_steps = 50L
    , outputs = c("infection", "reports")
  )
  |> mp_trajectory()
  |> ggplot()
  + geom_line(aes(time, value, colour = matrix))
  + theme_bw()
)
