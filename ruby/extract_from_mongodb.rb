require 'mongo'

class CSV

    def initialize(filename)
        @file = File.open(filename, 'w')
    end

    def add_header
        @file.puts('Issue;Comment;Project;Bot;Author;Mentioned;Created;Updated')
    end

    def write_csv_entry(issue, comment, project, bot, author, mentioned, cdate, udate)
        @file.puts([issue,comment,project,bot,author,mentioned,cdate,udate].join(';'))
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
    bot = "Dependabot"
    mentioned = false
    client[:comments].find(:issue_url => issue_url).each do |comment|
        comment_url = comment[:url]
        author_url = comment[:user][:url]
        comment_cdate = comment[:created_at]
        comment_udate = comment[:updated_at]
        csv.write_csv_entry(
            issue_url, comment_url, project, bot, author_url, mentioned, comment_cdate, comment_udate 
        )
        counter += 1
        if counter % prct == 0 then
            puts "Handled #{(counter / prct).to_i}% of comments."
        end
    end
end