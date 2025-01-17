source("workflow/scripts/log_smk.R")
library(cowplot)
library(ggtext)
library(glue)
library(here)
library(schtools)
library(tidyverse)

#create variables in local environment so they don't have to come from snakemake
feat_dat <- read_csv("results/feature-importance_results_aggregated.csv")

# Kelly's script below
percent_ci <- 75
filter_top_feats <- function(feat_dat, 
                             frac_important_threshold = 0.75,
                             otu_col = names#, 
                             #outcome_col = outcome,
                             #ds_col = dataset
                             ) {
  n_models <- feat_dat %>% pull(seed) %>% unique() %>% length()
  message(glue("# models: {n_models}"))
  feat_dat %>%
    mutate(is_important = perf_metric_diff > 0) %>%
    filter(is_important) %>%
    group_by({{ otu_col }}#, 
             #{{ outcome_col }},
             #{{ ds_col }}
             ) %>%
    summarise(
      frac_important = sum(is_important) / n_models,
      mean_perf_diff = mean(perf_metric_diff)
    ) %>%
    filter(frac_important >= frac_important_threshold) %>%
    arrange(by = desc(mean_perf_diff)) 
}

model_colors <- RColorBrewer::brewer.pal(4, 'Dark2')
names(model_colors) <- c("idsa", 'attrib', 'allcause', 'pragmatic')

dat <- read_csv("results/feature-importance_results.csv") %>% 
  rename(names = names)


# tax_dat <- schtools::read_tax("data/mothur/alpha/cdi.taxonomy")
# alpha_level <- 0.05
# 
# dat <- left_join(feat_dat, tax_dat, by = 'otu') %>% filter(dataset == 'full')

dat_top_otus <- dat %>% 
  filter_top_feats(frac_important_threshold = percent_ci/100) %>% 
  mutate(is_signif = TRUE)

top_otus_order <- dat_top_otus %>% 
  group_by(names) %>% 
   summarize(max_med = max(mean_perf_diff)) %>% 
   filter(max_med >= 0.0001) %>% 
   arrange(max_med) %>% 
   pull(names)
dat_top_otus <- dat_top_otus %>% filter(names %in% top_otus_order)

top_feats_dat <- dat %>% 
  filter(names %in% top_otus_order, 
         #!(dataset == 'int' & outcome == 'pragmatic')
         ) %>% 
  left_join(dat_top_otus, 
            by = c('names'#,
                   #'outcome', 
                   #'dataset'
                   )) 

relabun_dat <- data.table::fread(here('data', 'mothur', 'alpha', 
                                      'cdi.opti_mcc.shared')) %>% 
  calc_relabun() %>% 
  right_join(left_join(read_csv(here('data', 'process', 'cases_full_metadata.csv')),
                       data.table::fread(here('data', 'SraRunTable.csv')) %>% 
                         select(-Group) %>% 
                         rename(sample_id = sample_title,
                                sample = Run) %>% 
                         select(sample_id, sample), by = 'sample_id')) %>% 
  select(sample_id, otu, rel_abun, idsa, attrib, allcause, pragmatic) %>% 
  pivot_longer(c(idsa, attrib, allcause, pragmatic), 
               names_to = 'outcome', values_to = 'is_severe')

relabun_means <- relabun_dat %>% 
  group_by(outcome, is_severe, otu) %>% 
  filter(!is.na(is_severe)) %>% 
  summarize(med_rel_abun = mean(rel_abun)) %>% 
  left_join(tax_dat, by = 'otu')

tiny_constant <- relabun_dat %>%
  filter(rel_abun > 0) %>%
  slice_min(rel_abun) %>%
  pull(rel_abun) %>% .[1]/10 # select tiniest non-zero relabun and divide by 10

top_feats_means <- top_feats_dat %>% 
  group_by(dataset, outcome, tax_otu_label) %>% 
  summarize(med_auroc_diff = mean(perf_metric_diff),
  ) %>% 
  full_join(relabun_means %>% 
              filter(names %in% top_otus_order) %>% 
              select(outcome, tax_otu_label, med_rel_abun),
            relationship = 'many-to-many')
top_feats_means %>% 
  write_csv(here('results', 'top_features.csv'))

# FEATURE IMPORTANCE
 top_feats_dat %>% 
  #filter(dataset == 'full') %>% 
  mutate(
        #names = factor(names, levels = top_otus_order),
         #dataset = case_when(dataset == 'full' ~ 'Full datasets',
         #                    TRUE ~ 'Intersection'),
         #outcome = factor(outcome, levels = c('idsa', 'allcause', 'attrib', 'pragmatic')),
         is_signif = factor(case_when(is.na(is_signif) ~ 'No',
                                      TRUE ~ 'Yes'),
                            levels = c('Yes', 'No')
         )
  ) %>% 
  ggplot(aes(x = perf_metric_diff, 
             y = names, 
             #color = outcome,
             shape = is_signif,
             size = is_signif))+
  stat_summary(fun = 'mean', 
               fun.max = function(x) quantile(x, 0.75), 
               fun.min = function(x) quantile(x, 0.25),
               position = position_dodge(width = 0.9),
               alpha=0.6) +
  geom_hline(yintercept = seq(1.5, length(unique(top_otus_order))-0.5, 1), 
             lwd = 0.5, colour = "grey92") +
  geom_vline(xintercept = 0, linetype = 'dotted') +
  scale_color_manual(values = model_colors,
                     #labels = c(idsa='IDSA', attrib='Attributable', allcause='All-cause', pragmatic='Pragmatic'),
                     guide = guide_legend(label.position = "bottom",
                                          title = "Severity Definition",
                                          title.position = 'top',
                                          order = 2)) +
  scale_shape_manual(values = c(Yes=8, No=20),
                     guide = guide_legend(label.position = 'bottom',
                                          title = glue('Significant\n({percent_ci}% CI)'),
                                          title.position = 'top',
                                          order = 1)) +
  scale_size_manual(values = c(Yes=0.4, No=0.2),
                    guide = guide_legend(label.position = 'bottom',
                                         title = glue('Significant\n({percent_ci}% CI)'),
                                         title.position = 'top',
                                         order = 1)
  ) +
  labs(title=NULL, 
       y=NULL,
       x="Difference in AUROC") +
  theme_sovacool() +
  theme(text = element_text(size = 14, family = 'Helvetica'),
        axis.text.y = element_markdown(size = 10),
        axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
        strip.background = element_blank(),
        panel.spacing = unit(1, 'pt'),
        legend.position = "top",
        panel.grid.major.y = element_blank(),
        plot.margin = margin(0,5,0,0, unit = 'pt'),
        legend.box.margin = margin(0,0,0,0, unit = 'pt'),
        legend.margin = margin(0,0,0,0, unit = 'pt')) 

# RELATIVE ABUNDANCE
relabun_plot <- relabun_means %>% 
  filter(names %in% top_otus_order) %>% 
  mutate(names = factor(names, levels = top_otus_order),
         outcome = factor(outcome, levels = c('idsa', 'allcause', 'attrib', 'pragmatic')),
         med_rel_abun = med_rel_abun + tiny_constant,
         is_severe = factor(str_to_sentence(is_severe),
                            levels = c('Yes', 'No')),
         dataset = 'Full datasets'
  ) %>% 
  ggplot(aes(x = med_rel_abun, y = names,
             color = outcome, shape = is_severe, group = outcome)) +
  geom_point(position = position_dodge(width = 0.9),
             alpha=0.6) +
  geom_hline(yintercept = seq(1.5, length(unique(top_otus_order))-0.5, 1), 
             lwd = 0.5, colour = "grey92") +
  geom_vline(xintercept = tiny_constant, linetype = 'dashed') +
  scale_color_manual(values = model_colors,
                     labels = c(idsa='IDSA', attrib='Attributable', 
                                allcause='All-cause', pragmatic='Pragmatic')
  ) +
  scale_shape_manual(values = c(Yes=3, No=1),
                     guide = guide_legend(label.position = 'bottom',
                                          title = 'Is Severe',
                                          title.position = 'top')) +
  guides(color = 'none') +
  scale_x_log10(breaks = scales::trans_breaks('log10', function(x) 10^x),
                labels = scales::trans_format('log10', scales::math_format(10^.x))) +
  labs(x = expression(''*log[10]*' Rel. Abundance')) +
  theme_sovacool() +
  theme(text = element_text(size = 14, family = 'Helvetica'),
        axis.text.y = element_blank(),
        axis.title.y = element_blank(),
        axis.ticks.y = element_blank(),
        axis.text.x = element_text(size = 10),
        panel.grid.major.y = element_blank(),
        strip.background = element_blank(),
        legend.position = 'top',
        legend.box.margin = margin(0,0,0,0, unit = 'pt'),
        legend.margin = margin(0,0,0,0, unit = 'pt'),
        plot.margin = margin(0,8,0,0))

fig <- plot_grid(feat_imp_plot, relabun_plot,
                 ncol = 2, rel_widths = c(1, 0.4), align = 'h', axis = 'tb')

#create in the plot window, delete later
plot_grid(feat_imp_plot, relabun_plot,
          ncol = 2, rel_widths = c(1, 0.4), align = 'h', axis = 'tb')

ggsave(
  filename = here('figures', 'feature-importance_full.png'), 
  plot = fig,
  device = "png", dpi = 600, 
  units = "in", width = 8.5, height = 4.5 # https://journals.asm.org/figures-tables
)
