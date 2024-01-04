#### Basic loading of data and analysis

## Encoding: Windows-1250
## Created:  2024-01-04 FrK
## Edited:   2024-01-04 FrK

## NOTES:
## 
## 


# Head --------------------------------------------------------------------

# Clearing
rm(list = ls())

# Packages
library(tidyverse)



# Loading -----------------------------------------------------------------

# Getting list of files with results
fl = list.files(pattern = "res_")

# Loading
## First file 
fn = fl[[1]]
tb = read_csv(fn) %>% mutate(file_name = fn)

## Other files
for (f in 2:length(fl)) {
  fn = fl[[f]]
  tb = tb %>% add_row(read_csv(fn) %>% mutate(file_name = fn))
}

## Metadata
tm = str_split_fixed(as_tibble(fl)$value, pattern = "_", n = 10)[,2:10] %>% 
  as_tibble() %>% 
  mutate(
    across(everything(), ~ parse_number(.x)),
    file_name = as_tibble(fl)$value)
names(tm)[1:9] = c("P", "F", "Tree_radiation", "Mass_heat_ratio", "Mass_ashes_ratio", "Ashes_retention_ratio", "Ashes_mass_ratio", "Transiency", "Stop_at")

## Joining data with metadata
tb = right_join(tm, tb)



# The first graphs --------------------------------------------------------

tb %>% 
  ggplot() +
  aes(x = mass_burnt) +
  facet_grid(F ~ P) +
  geom_histogram() +
  scale_x_log10() +
  theme_classic()


tb %>% 
  ggplot() +
  aes(x = mass_grown) +
  facet_grid(Tree_radiation ~ Mass_heat_ratio) +
  geom_histogram() +
  scale_x_log10() +
  scale_y_log10() +
  theme_classic()



