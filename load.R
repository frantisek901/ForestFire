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

# Loading updated model data
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
    Burn_neis4 = FALSE,
    file_name = as_tibble(fl)$value)
names(tm)[1:9] = c("P", "F", "Tree_radiation", "Mass_heat_ratio", "Mass_ashes_ratio", "Ashes_retention_ratio", "Ashes_mass_ratio", "Transiency", "Stop_at")

## Joining data with metadata
tb = right_join(tm, tb)


# Getting list of files with results on old-school forest fire
fl = list.files(pattern = "old_")

# Loading old-school forest fire data
## First file 
fn = fl[[1]]
ta = read_csv(fn) %>% mutate(file_name = fn)

## Other files
for (f in 2:length(fl)) {
  fn = fl[[f]]
  ta = ta %>% add_row(read_csv(fn) %>% mutate(file_name = fn))
}

## Metadata
tm = str_split_fixed(as_tibble(fl)$value, pattern = "_", n = 10)[,2:10] %>% 
  as_tibble() %>% 
  mutate(
    across(everything(), ~ parse_number(.x)),
    Burn_neis4 = TRUE,
    file_name = as_tibble(fl)$value)
names(tm)[1:9] = c("P", "F", "Tree_radiation", "Mass_heat_ratio", "Mass_ashes_ratio", "Ashes_retention_ratio", "Ashes_mass_ratio", "Transiency", "Stop_at")

## Joining data with metadata
ta = right_join(tm, ta)


# Merging both files
tc = add_row(ta, tb) %>% 
  # Hmm... I found some mistakes -- trees should be grown with mass 1 not 0... 
  mutate(
    mass_grown = if_else(!Burn_neis4 & Tree_radiation == 0, mass_grown, mass_grown + trees_grown),
    mass_burnt = if_else(!Burn_neis4 & Tree_radiation == 0, mass_burnt, mass_burnt + trees_burnt),
    trees_mass = if_else(!Burn_neis4 & Tree_radiation == 0, trees_mass, trees_mass + trees_count)
  )


# The first graphs --------------------------------------------------------

tb %>% 
  ggplot() +
  aes(x = mass_burnt) +
  facet_grid(F ~ P, labeller = "label_both") +
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


ta %>% 
  ggplot() +
  aes(x = mass_burnt) +
  facet_grid(F ~ P, labeller = "label_both") +
  geom_histogram() +
  scale_x_log10() +
  scale_y_log10() +
  theme_classic()


tc %>%
  filter(P %in% c(1, 100, 1000), F %in% c(1, 100, 1000), Tree_radiation %in% c(0)) %>% 
  # count(Burn_neis4)
  ggplot() +
  aes(x = trees_count, fill = Burn_neis4) +
  facet_grid(rows = vars(F), cols = vars(P), labeller = "label_both", scales = "free_x") +
  geom_density(alpha = 0.5) +
  scale_x_log10() +
  # scale_y_log10() +
  theme_classic()


tc %>%
  filter(P %in% c(1, 100, 1000), F %in% c(1, 100, 1000), Tree_radiation %in% c(0)) %>% 
  # count(Burn_neis4)
  ggplot() +
  aes(y = mass_grown, x = Burn_neis4, fill = Burn_neis4) +
  facet_grid(rows = vars(F), cols = vars(P), labeller = "label_both", scales = "free_y") +
  geom_boxplot() +
  # scale_x_log10() +
  scale_y_log10() +
  theme_classic()


tc %>%
  filter(P %in% c(1, 100, 1000), F %in% c(1, 100, 1000), # !Burn_neis4,
         Tree_radiation %in% c(0)) %>% 
  # count(Burn_neis4, Ashes_mass_ratio)
  ggplot() +
  aes(y = mass_burnt, x = mass_grown, col = factor(Ashes_mass_ratio)) +
  facet_grid(rows = vars(F), cols = vars(P), labeller = "label_both", scales = "fixed") +
  geom_point(alpha = 0.1) +
  scale_x_log10() +
  scale_y_log10() +
  theme_classic()



count(tb, Tree_radiation)

