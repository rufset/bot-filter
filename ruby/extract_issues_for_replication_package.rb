require 'mongo'
require 'json'
require 'fileutils'

client = Mongo::Client.new(['127.0.0.1'], :database => 'gh-issues')

prefix = 'https://api.github.com/repos/'
id_file = ARGV[0]
target_dir = ARGV[1]
File.open(id_file, 'r').each_line do |line|
    issue = line.chomp
    id = prefix+issue
    path = target_dir+'/'+issue
    FileUtils.mkpath(path)
    File.open(path+'/issue.json', 'w') do |f|
        f.write(JSON.pretty_generate(client[:issues].find({:url => id}).first))
    end
    comment_ids = []
    client[:comments].find({:issue_url => id}).each do |comment|
        id = comment[:id].to_s
        next if comment_ids.include? id
        comment_ids << id
        File.open(path+'/comment_'+id+'.json', 'w') do |f|
            f.write(JSON.pretty_generate(comment))
        end        
    end
end