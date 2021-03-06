require 'mongo'

class CSV

    def initialize(filename)
        @file = File.open(filename, 'w')
    end

    def add_header
        @file.puts('Issue;Comment;Project;Bot;IAuthor;CAuthor;IMentioned;CMentioned;BotIsIAuthor;BotIsCAuthor;ICreated;IUpdated;CCreated;CUpdated;IState;ICloseDate;IIsPR;IsMerged;MergeDate')
    end

    def write_csv_entry(issue, comment, project, bot, author_issue, author_comment, mentioned_issue, mentioned_comment,
        bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state,
        issue_close_date, issue_pr, merged, merge_date)
        @file.puts([issue, comment, project, bot, author_issue, author_comment, mentioned_issue, mentioned_comment,
        bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state,
        issue_close_date, issue_pr, merged, merge_date].join(';'))
    end

end

# Not convinced this is a great idea, but it's too funny not to do it here :)
# (rather than checking for all fields if they are nil before doing string search,
#  we add an include? method to the nil object that always returns falses)
class NilClass
  def include?(s)
    false
  end
  def downcase
    return self
  end
end

$stdout.sync = true # disable output buffering, required for non-interactive consoles

client = Mongo::Client.new(['127.0.0.1'], :database => 'gh-issues')
csv = CSV.new(ARGV[0])
csv.add_header

bot_project_dir = ARGV[1]
bot_project_mappings = {}
Dir.foreach(bot_project_dir) do |projects_file|
    qf = bot_project_dir+'/'+projects_file
    next if File.directory?(qf)
    m = []
    File.open(qf, 'r').each_line{ |l| m << l.chomp! }
    bot_project_mappings[projects_file.sub(".txt", "").sub("projects-", "")] = m
end
all_bots = bot_project_mappings.keys

issue_count = client[:issues].count()

used_ids = []

counter = 0
client[:issues_merged].find().no_cursor_timeout.each do |issue|

    counter += 1
    puts "Handling issue #{counter} from #{issue_count}"

    issue_id = issue[:id]
    if used_ids.include? issue_id then
        next
    else
        used_ids << issue_id
    end

    project = issue[:repository_url].sub("https://api.github.com/repos/", "")
    bots = bot_project_mappings.select{ |k,v| v.include?(project) }.keys

    # find which bots have been mentioned in title or body
    mentioned_issue = all_bots.select do |bot|
        issue[:title].downcase.include?(bot) || issue[:body].downcase.include?(bot)
    end
    mentioned_issue = mentioned_issue.join(',')

    # find which bots have authored this
    issue_author = issue[:user][:login]
    bot_is_issue_author = bots.select do |bot|
        issue_author.downcase.include?(bot)
    end
    bot_is_issue_author = bot_is_issue_author.join(',')

    issue_url = issue[:url]
    issue_cdate = issue[:created_at]
    issue_udate = issue[:updated_at]
    issue_state = issue[:state]
    issue_close_date = issue[:closed_at]
    issue_is_pr = issue[:pull_request] != nil

    # check if this issue has been merged (if there is a merge event for it)
    # and when the last merge was
    merge_events = issue[:merge_event]
    merged = merge_events.count > 0
    if merged then
        merge_date = merge_events.max{ |a,b| (a[:created_at] != 0 || 0) <=> (b[:created_at]!=0 || 0) }[:created_at]
    else
        merge_date = ''
    end

    used_comments = []
    client[:comments].find(:issue_url => issue_url).no_cursor_timeout.each do |comment|
        comment_id = comment[:id]
        if used_comments.include? comment_id then
            next
        else
            used_comments << comment_id
        end

        comment_url = comment[:url]
        comment_author = comment[:user][:login]
        comment_cdate = comment[:created_at]
        comment_udate = comment[:updated_at]

        mentioned_comment = all_bots.select do |bot|
            comment[:body].downcase.include?(bot)
        end
        mentioned_comment = mentioned_comment.join(',')

        bot_is_comment_author = bots.select do |bot|
            comment_author.downcase.include?(bot)
        end
        bot_is_comment_author = bot_is_comment_author.join(',')

        csv.write_csv_entry(
            issue_url, comment_url, project, bots.join(','), issue_author, comment_author, mentioned_issue, mentioned_comment,
            bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state,
            issue_close_date, issue_is_pr, merged, merge_date
        )
    end
end
