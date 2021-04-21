library(scales)
library(tidyverse)
library(lubridate)
library(viridisLite)
library(survival)
library(survminer)

CHOSEN_BOTS <- c("dependabot", "greenkeeper", "depfu", "snyk", "pyup", "renovate")
                 #"scala-steward", "whitesource", "dpebot", "imgbot") Removed these <---

# List of bot aliases used
#scala Steward;scala-steward;scala-steward-bot
#dependabot;app/dependabot;app/dependabot-preview;dependabot-bot
#greenkeeper;greenkeeperio-bot;greenkeeper-keeper-bot;app/greenkeeper;app/greenkeeperio-bot
#renovatebot;app/renovatebot;renovatebot
#Snyk-bot;snyk-bot;app/snyk
#pyup-bot;pyupio;pyup-vuln-bot;pyup-bot
#dpebot;dpebot
#depfu;depfu-bot;app/depfu
#imgbot;ImgBotApp;app/imgbot
#whitesource;app/whitesource-bolt-for-github

# Constants used to tag different types of project activities
# TODO: Check to see whether this will really be useful.
HUMAN_ACTIVITY     <- "human"   # Issue / Comment was made by a human
PROJ_EXACT_MATCH   <- "match"   # Issue / Comment was made by a bot for which the project was selected
PROJ_PARTIAL_MATCH <- "partial" # Issue / Comment was made by another bot and not the intended one.

# Function to parse / clean the bot names and identify the authors of comments and issues.
# If the bot belongs to our CHOSEN_BOTS collection, we parse which specific bot is the author,
#    but if the bot is not in our list and we do string matching for bot names, we classify it
#    as "other bots" (e.g., imgbot, repository specific bots) and lastly, if it is not in any of
#    those cases, we classify as humans.
parse_bot <- function(raw_bot_name){
  parsed_name <- ""
  if(grepl(raw_bot_name, pattern = "renovate.*bot", ignore.case = TRUE)){
    parsed_name <- "renovatebot"
    
  }else if(grepl(raw_bot_name, pattern = "dependa.*bot", ignore.case = TRUE)){
    parsed_name <- "dependabot"
    
  }else if(grepl(raw_bot_name, pattern = "green.*keeper", ignore.case = TRUE)){
    parsed_name <- "greenkeeper"
    
  }else if(grepl(raw_bot_name, pattern = "pyup", ignore.case = TRUE)){
    parsed_name <- "pyup"
    
  }else if(grepl(raw_bot_name, pattern = "depfu", ignore.case = TRUE)){
    parsed_name <- "depfu"
  
  # These bots were removed to keep the analysis short. Can add again in future studies.
  #}else if(grepl(raw_bot_name, pattern = "snyk", ignore.case = TRUE)){
  #  parsed_name <- "snyk"
  #}else if(grepl(raw_bot_name, pattern = "dpebot", ignore.case = TRUE)){
  #  parsed_name <- "dpebot"
  #}else if(grepl(raw_bot_name, pattern = "imgbot", ignore.case = TRUE)){
  #  parsed_name <- "imgbot"
  #}else if(grepl(raw_bot_name, pattern = "whitesource", ignore.case = TRUE)){
  #  parsed_name <- "whitesource"
  #}else if(grepl(raw_bot_name, pattern = "scala.*steward", ignore.case = TRUE)){
  #  parsed_name <- "scala-steward"
    
  }else if(grepl(raw_bot_name, pattern = "bot", ignore.case = TRUE) |
           grepl(raw_bot_name, pattern = "snyk", ignore.case = TRUE)|
           grepl(raw_bot_name, pattern = "whitesource", ignore.case = TRUE) |
           grepl(raw_bot_name, pattern = "scala.*steward", ignore.case = TRUE)
           ){
    parsed_name <- "other bot"
    
  }else{
    parsed_name <- "human"
  }
  return(parsed_name)
}
parse_bot_v <- Vectorize(parse_bot) #Vectorise the function to be used rowwise by dplyr.

# Classify the activity based on the intended goal. For instance, if the author of the issue
#   is dependabot, and the project was previously tagged as a dependabot project, then it is a full match
#   However, if the project was not previously tagged as a dependabot project, then it is a partial match.
classify_project_activity <- function(actor, project_bots){
  activity <- ""
  if(actor == "human"){
    activity <- HUMAN_ACTIVITY
  }else if(actor %in% project_bots){
    activity <- PROJ_EXACT_MATCH
  }else {
    activity <- PROJ_PARTIAL_MATCH #TODO: Will we really use this if not, we can remove.
  }
  return(activity)
}
classify_project_activity_v <- Vectorize(classify_project_activity) #Vectorize so it can be used rowwise.

# Variable to standardize plotting theme.
PLOT_THEME <-  theme_minimal(base_size = 10) + 
  theme(plot.title = element_text(size = 12, face = "bold", hjust = 0.5),
        panel.grid.minor = element_blank(),legend.position = "bottom", 
        axis.line = element_line(size = 1), axis.ticks = element_line(size = 1),
        axis.text.x = element_text(angle = 90, hjust = 1),
        strip.background = element_rect(colour = "white", fill = "aliceblue"))

# -----------------------------------------------------------------
#   START OF THE SCRIPT
# -----------------------------------------------------------------

raw_df <-  read.csv2("../issues.csv", header = TRUE, sep = ";")

# Identify rows of issues that were not mapped to any bot.
weird_rows <- raw_df %>% filter(Bot == "") %>% group_by(Project) %>% tally(name = "Comments")

# Add columns and filter the raw data into the main dataframe used in this script.
issues_df <- raw_df %>% 
  filter(Bot != "") %>% 
  mutate(Issue   = str_replace(string = Issue  , pattern = "https://api.github.com/repos/", replacement = ""),
         Comment = str_replace(string = Comment, pattern = "https://api.github.com/repos/", replacement = ""),
         IssueAuthor = parse_bot_v(IAuthor),
         ComAuthor = parse_bot_v(CAuthor),
         IDate = strftime(as.Date(ICreated), format = "%y-%m"), 
         IMonthDate = floor_date(as.Date(ICreated), "month"),
         ComIMonthDate = floor_date(as.Date(CCreated), "month")) %>% 
  mutate( PIType = classify_project_activity_v(IssueAuthor, str_split(Bot, pattern = ",")[[1]]),
          PCType = classify_project_activity_v(ComAuthor  , str_split(Bot, pattern = ",")[[1]]))

# Table only with issues.
only_issues <- issues_df %>% group_by(Project, Bot, Issue, IMonthDate, IDate, IIsPR) %>% 
  summarise(Author=paste(unique(IssueAuthor),collapse=', '),
            Commentators=paste(ComAuthor,collapse=', '),
            ThreadSize = n_distinct(Comment),
            IMentions = paste(unique(IMentioned),collapse=', '),
            CMentions = paste(unique(CMentioned),collapse=', '),) %>% 
  rowwise() %>% 
  mutate( ChosenBotComments = str_extract_all(Commentators, pattern = paste(CHOSEN_BOTS, collapse = "|"))[[1]] %>% length,
          HumanComments     = str_extract_all(Commentators, pattern = "human")[[1]] %>% length,
          OtherBotsComments = str_extract_all(Commentators, pattern = "other bot")[[1]] %>% length)

# TODO: When couting issues, do I remove human authors? For now, yes.
issues_per_month_df <- issues_df %>% filter(IssueAuthor != "human") %>%
  group_by(Project, Bot, IMonthDate, IssueAuthor) %>% 
  summarise(NIssues = n_distinct(Issue)) %>%
  group_by(Project) %>% 
  mutate(TotalIssues = sum(NIssues)) %>% 
  filter(TotalIssues > 100) #IMPORTANT: Filters only projects with many issues

# Split the issues per month in a bar chart.
issues_p_month_plot <- ggplot(issues_per_month_df, aes(x = IMonthDate, y = NIssues, fill = IssueAuthor)) +
  geom_bar(stat="identity", position = "stack") +
  scale_x_date(date_labels = "%y-%m", date_breaks = "1 month") +
  scale_fill_viridis_d()+
  labs(title = "Issues created by Bots per Month", y = "Num of Issues", x = "Year-Month") +
  PLOT_THEME
ggsave(issues_p_month_plot, filename = "all_projects.pdf", width = 30, units = "cm", device = "pdf")


for(project in unique(issues_per_month_df$Project)){
  project_df <- issues_per_month_df %>% filter(Project == project)
  proj_month_plot <- ggplot(project_df, aes(x = IMonthDate, y = NIssues, fill = IssueAuthor)) +
    geom_bar(stat="identity", position = "stack") +
    scale_x_date(date_labels = "%y-%m", date_breaks = "1 month") +
    scale_fill_viridis_d()+
    facet_wrap(~IssueAuthor, ncol = 1, scales = "free_y") +
    labs(title = paste(project," - Bot issues per Month",sep=""), y = "Num of Issues", x = "Year-Month") +
    PLOT_THEME
  plot_filename <-paste("projs/",str_replace(string = project, pattern = "/", replacement = "-"),"_issues_monthly.pdf",sep="")
  ggsave(proj_month_plot, filename = plot_filename, width = 30, units = "cm", device = "pdf")
}

# Same as above but faceted by Bot combination.
# TODO: Update this to show per project and combinations of bots.
issues_p_month_plot_facet <- ggplot(issues_per_month_df, aes(x = IMonthDate, y = NIssues, fill = IssueAuthor)) +
  geom_bar(stat="identity", position = "stack") +
  #geom_line()+
  scale_x_date(date_labels = "%y-%m", date_breaks = "1 month") +
  scale_fill_viridis_d()+
  labs(title = "Issues created by Bots per Month", y = "Num of Issues", x = "Year-Month") +
  facet_wrap(~Bot, ncol = 1, scales = "free_y") +
  PLOT_THEME
ggsave(issues_p_month_plot_facet, filename = "all_projects_facet.pdf", width = 25, height = 30, units = "cm", device = "pdf")

selected_projects <- unique(issues_per_month_df$Project)

numissues_df <- only_issues %>% group_by(Project, Author) %>% 
  summarise(NIssues = n_distinct(Issue)) %>% 
  filter(Project %in% selected_projects)

issues_p_bot_plot <- ggplot(numissues_df, aes(x = Author, y = NIssues, fill = Author)) + geom_boxplot() +
  labs(title = "Num of Issues per Author (Filtered Projects)", y = "Num of Issues") +
  scale_y_continuous(limits = c(0,max(numissues_df$NIssues)), breaks = seq(0,max(numissues_df$NIssues), by = 100)) +
  PLOT_THEME
ggsave(issues_p_bot_plot, filename = "issues_p_bot.pdf", width = 15, height = 15, units = "cm", device = "pdf")


ggplot(only_issues %>% filter(Project %in% selected_projects), aes(y = ThreadSize, x = Author, fill = Author)) +
  geom_boxplot()


# ---------------------------------------
# Cases for qualitative analysis: Check this later.
# ---------------------------------------

comments_df <- issues_df %>% group_by(Project, ComAuthor) %>% 
  summarise(NComments = n_distinct(Comment)) %>%
  group_by(Project) %>% 
  mutate(TotalComments = sum(NComments))

comments_plot <- ggplot(comments_df, aes(y = NComments, x = Project, fill = ComAuthor)) +
  #scale_fill_viridis_d() +
  geom_bar(stat="identity", position = "stack") +
  labs(title = "Num of Comments per Project and Author") +
  PLOT_THEME
ggsave(comments_plot, filename = "comments_p_project.pdf", width = 25, height = 20, units = "cm", device = "pdf")

comments_plot2 <- ggplot(comments_df, aes(y = NComments, x = ComAuthor, fill = ComAuthor)) +
  scale_fill_viridis_d() +
  geom_bar(stat="identity", position = "stack") +
  labs(title = "Num of Comments per Author") +
  PLOT_THEME
ggsave(comments_plot2, filename = "comments_p_author.pdf", width = 15, height = 15, units = "cm", device = "pdf")

# ---------------------------------------
# Tables or Plots that we can use in the paper
# ---------------------------------------
# Gets a table that summarises the number of issues, comments and projects per combinations of bots.
table_1 <- issues_df %>% group_by(Bot) %>% summarise(NIssue = n_distinct(Issue), 
                                                     NComments = n_distinct(Comment), 
                                                     NProjects = n_distinct(Project))