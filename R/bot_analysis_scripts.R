library(gridExtra)
library(tidyverse)
library(ggrepel)
library(viridis)

save_table_to_pdf <- function(data_frame, filename){
  pdf(filename)       # Export PDF
  grid.table(data_frame)
  dev.off()
}
  

#Color-blind friendly palette with 7 values.
cbbPalette <- c("#CC79A7", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#000000")

BOT_CSV_PATH <- "../ruby/watchers/"
bot_names <- c("imgbot","snyk","pyup","whitesource","greenkeeper","dependabot","renovate")

PLOT_THEME_SCATTER <- theme_minimal(base_size = 10) + 
  theme(plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
        panel.grid.minor = element_blank(),legend.position = "bottom", 
        axis.line = element_line(size = 1), axis.ticks = element_line(size = 1),
        strip.background = element_rect(colour = "white", fill = "aliceblue"))

# --------------------------------------------------------------------
# Data cleaning and processing
# Goes through all files and build a big DataFrame with all bots.
# --------------------------------------------------------------------
all_bots_df <- data.frame()
for(bot_name in bot_names){
  bots_df <- read.csv2(paste(BOT_CSV_PATH,bot_name,".csv",sep=""),header = TRUE, sep= ";")
  bots_df2 <- bots_df %>% filter(is_forked == "false") %>%  
    group_by(project) %>% 
    summarise(watchers = max(watchers), stargazers = max(stargazers),
              subscribers = max(subscribers), forks = max(forks)) %>% 
    mutate("BotName" = bot_name)
    
  all_bots_df <- bind_rows(all_bots_df, bots_df2)
}

# --------------------------------------------------------------------
# Creating different tables.
# Goes through all files and build a big DataFrame with all bots.
# --------------------------------------------------------------------
projects_per_bot <- all_bots_df %>% 
  group_by(BotName) %>% 
  tally(name = "TotalProjects") %>% 
  mutate(Perc = round(100*TotalProjects/nrow(all_bots_df),2)) %>% 
  arrange(-TotalProjects)
save_table_to_pdf(projects_per_bot, "output/projects_per_devbot.pdf")

multibot_projects_df <- all_bots_df %>% 
  group_by(project) %>% 
  mutate(ListDevBots = paste(BotName, collapse = ",")) %>% 
  group_by(project, ListDevBots) %>% 
  tally(name = "NumOfDevBots") %>%
  arrange(-NumOfDevBots)

write.table(multibot_projects_df %>% filter(NumOfDevBots >1 ), "./output/multibot_projects.csv", sep=";")

# Table that shows the proportion of multiple bots in different projects.
# For instance: X% of the projects have 3 bots
multibot_summary_df <- multibot_projects_df %>% 
  group_by(NumOfDevBots) %>% count(NumOfDevBots, name = "Count") %>% 
  mutate(Perc = round(100*Count/nrow(multibot_projects_df),2))
save_table_to_pdf(multibot_summary_df, "output/projects_with_many_devbots.pdf")

# Not sure this is a good measure. Perhaps remove this table.
popular_bots_df <- multibot_summary_df %>% 
  arrange(-subscribers, -watchers, Count) %>% 
  head
popular_bots_df

# ----------------------------------------------------------------------
# Some plots:                     
# ----------------------------------------------------------------------

# Show names of the bots with more than 500 watchers and subscribers
# TODO: Rethink this plot, too crowded with information. Table better?!
plot_popularity <- ggplot(all_bots_df, aes(x = subscribers, y = watchers)) + 
  geom_point(alpha = 0.25, aes(color = BotName)) + 
  scale_fill_manual(values = cbbPalette) +
  geom_label_repel(data = filter(all_bots_df, watchers>500 & subscribers > 500),aes(label=project), max.overlaps = ) +
  PLOT_THEME_SCATTER +
  facet_wrap(~BotName, ncol = 4, scales = "free")
ggsave(plot_popularity, filename = "output/devbot_popularity.png", device = "png", width = 45, height = 25, units = "cm")

# Histogram of the distribution of watchers. Not good, because too many projects have few watchers.
plot_watch_histogram <- ggplot(all_bots_df, aes(x = watchers)) + 
  geom_histogram(binwidth = 100) + 
  facet_wrap(~BotName, ncol = 4, scales = "free") + 
  PLOT_THEME_SCATTER
ggsave(plot_watch_histogram, filename = "output/devbot_histogram.png", device = "png", width = 45, height = 25, units = "cm")

# Donut chart, but without the % values (TODO: add lab position column and then geom_text)
ggplot(projects_per_bot, aes(x = 2, y = Perc)) + geom_bar(stat= "identity", color = "white", aes(fill = BotName)) +
  coord_polar(start = 0, theta = "y") + 
  scale_fill_manual(values = cbbPalette) +
  xlim(c(0.5, 2.5)) +
  theme_void()
  
# Same information as the donut but perhaps clearer since its ordered
plot_devbot_projects <- ggplot(projects_per_bot, aes(x = reorder(BotName, -Perc), y = Perc)) + 
  geom_bar(stat= "identity", color = "white", aes(fill = BotName)) +
  geom_text(aes( label = paste(Perc,"%")), vjust = -.5) +
  scale_y_continuous(limits = c(0,50),breaks = seq(0,50,by=10)) +
  labs(y = "Percent", fill="DevBots", x = "") +
  scale_fill_manual(values = cbbPalette) +
  PLOT_THEME_SCATTER
ggsave(plot_devbot_projects, filename = "output/devbot_projects.png", device = "png", width = 15, height = 10, units = "cm")

