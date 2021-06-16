require 'octokit'
require 'mongo'

    def waitForRateLimit(client, event)
        if client.rate_limit.remaining <= 0 then
            puts "Rate limit reached, sleeping until #{client.rate_limit.resets_at.to_s}"
            sleepTime = client.rate_limit.resets_at - Time.now + 120
            sleep(sleepTime) unless sleepTime <= 0
        end
        return github.get(event[:url]).to_hash
    end

    # def checkIfAlreadyDownloaded(event, mongo)
    #     dl_event = mongo[:merge_events].find({'node_id' => event[:node_id]})
    #     return dl_event.count > 0
    # end

k1 = ARGV[0]
k2 = ARGV[1]
k3 = ARGV[2]

key1 = File.read(k1)
key2 = File.read(k2)
key3 = File.read(k3)

$stdout.sync = true # disable output buffering, required for non-interactive consoles

mongo = Mongo::Client.new(['127.0.0.1'], :database => 'gh-issues')
github = []
github[0] = Octokit::Client.new(:access_token => key1)
github[1] = Octokit::Client.new(:access_token => key2)
github[2] = Octokit::Client.new(:access_token => key3)

to_download = mongo[:events].count({'event' => 'merged'})
i = 0
gh_idx = 0

# find what we have already downloaded
already_downloaded = {}
mongo[:merge_events].find().no_cursor_timeout.each do |event|
    already_downloaded[event[:node_id]] = 1
    puts "Already downloaded #{event[:node_id]}"
end

mongo[:events].find({'event' => 'merged'}).no_cursor_timeout.each do |event|

    if already_downloaded.key?(event[:node_id]) then
        i += 1
        puts "Skipping #{event[:node_id]} (#{i}/#{to_download})"
        next
    end

    # TODO - refactor this into something sane!
    begin
        event_hash = github[gh_idx].get(event[:url]).to_hash
        mongo[:merge_events].insert_one(event_hash)
    rescue Octokit::TooManyRequests
        gh_idx +=1
        begin
            event_hash = github[gh_idx].get(event[:url]).to_hash
            mongo[:merge_events].insert_one(event_hash)
        rescue Octokit::TooManyRequests
            gh_idx +=1
            begin
                event_hash = github[gh_idx].get(event[:url]).to_hash
                mongo[:merge_events].insert_one(event_hash)
            rescue Octokit::TooManyRequests
                event_hash = waitForRateLimit(github[0], event)
                mongo[:merge_events].insert_one(event_hash)
            rescue 
                puts "Error: #{event[:url]}"
            end        
        rescue 
            puts "Error: #{event[:url]}"
        end
    rescue 
        puts "Error: #{event[:url]}"
    end
    already_downloaded[event[:node_id]] = 1
    i += 1
    puts "Inserted #{i}/#{to_download} event JSONs"
end