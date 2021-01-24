require 'mongo'

class CSV

    def initialize(filename)
        @file = File.open(filename, 'w')
    end

    def add_header
        @file.puts('Issue;Comment;Project;Bot;IAuthor;CAuthor;IMentioned;CMentioned;BotIsIAuthor;BotIsCAuthor;ICreated;IUpdated;CCreated;CUpdated;IState')
    end

    def write_csv_entry(issue, comment, project, bot, author_issue, author_comment, mentioned_issue, mentioned_comment,
        bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state)
        @file.puts([issue, comment, project, bot, author_issue, author_comment, mentioned_issue, mentioned_comment,
        bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state].join(';'))
    end

end

# Not convinced this is a great idea, but it's too funny not to do it here :)
# (rather than checking for all fields if they are nil before doing string search,
#  we add an include? method to the nil object that always returns falses)
class NilClass
  def include?(s)
    false
  end
end

client = Mongo::Client.new(['127.0.0.1'], :database => 'gh-issues')
csv = CSV.new(ARGV[0])
csv.add_header

comment_count = client[:comments].count()
prct = (comment_count / 100).to_i

counter = 0
client[:issues].find().each do |issue|
    issue_url = issue[:url]
    project = issue[:repository_url]
    bot = "dependabot"
    mentioned_issue = issue[:title].include?(bot) || issue[:body].include?(bot)
    issue_author = issue[:user][:login]
    bot_is_issue_author = issue_author.include?(bot)
    issue_cdate = issue[:created_at]
    issue_udate = issue[:updated_at]
    issue_state = issue[:state]

    client[:comments].find(:issue_url => issue_url).each do |comment|
        comment_url = comment[:url]
        comment_author = comment[:user][:login]
        comment_cdate = comment[:created_at]
        comment_udate = comment[:updated_at]
        mentioned_comment = comment[:body].include?(bot)
        bot_is_comment_author = comment_author.include?(bot)
        
        csv.write_csv_entry(
            issue_url, comment_url, project, bot, issue_author, comment_author, mentioned_issue, mentioned_comment,
            bot_is_issue_author, bot_is_comment_author, issue_cdate, issue_udate, comment_cdate, comment_udate, issue_state
        )
        counter += 1
        if counter % prct == 0 then
            puts "Handled #{(counter / prct).to_i}% of comments."
        end
    end
end