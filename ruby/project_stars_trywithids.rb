require 'octokit'
require 'time'

class ProjectList
    include Enumerable

    attr_accessor :projects

    def initialize
        @projects = []
    end

    def self.parse(file)
        list = ProjectList.new
        File.open(file, 'r').each_line do |line|
            org, p = line.split(/_/, 2)
            next unless p   # if the splitting didn't work (e.g., in the file header) let's just skip this line
            p.strip!
            list.projects << Project.new(org, p)
        end
        return list
    end

    def each(&block)
        @projects.each(&block)
    end

    def +(list)
        @projects += list.projects
        clearDuplicates
    end

    def sort!
        @projects.sort! { |a,b| b.metadata.watchers <=> a.metadata.watchers }
    end

    def print_to_file(file)
        header = 'project;watchers;stargazers;subscribers;forks;is_forked'
        File.open(file, 'w') do |f|
            f.puts header
            @projects.each{ |p| f.puts p.to_s }
        end
    end

    def clearDuplicates
        @projects.uniq!(&:name)
    end

end

class Project

    attr_accessor :metadata

    def initialize(org, name)
        @org = org
        @name = name
    end

    def name
        @org+'/'+@name
    end

    def to_s
        "#{name};#{@metadata.watchers};#{@metadata.stargazers};" +
        "#{@metadata.subscribers};#{@metadata.forks};#{@metadata.is_forked}"
    end

end

class ProjectMetadata

    attr_accessor :watchers
    attr_accessor :stargazers
    attr_accessor :subscribers
    attr_accessor :forks
    attr_accessor :is_forked

    def initialize(watchers, stargazers, subscribers, forks, forked)
        @watchers = watchers
        @stargazers = stargazers
        @subscribers = subscribers
        @forks = forks
        @is_forked = forked
    end

end

class ProjectFetcher

    def initialize
        @client = Octokit::Client.new(:access_token => "902e5ac3ffea0497bc3b3b052110c2615c8d5336")
    end

    def fetchProjectsForFile(file)
        projects = ProjectList.parse(file)
        projects.each do |project|
            
            checkRateLimit

            # fetch repo
            puts "Fetching #{project.name}"
            begin
                repo = @client.repo(project.name)
                metadata = ProjectMetadata.new(repo.watchers_count, repo.stargazers_count, repo.subscribers_count, repo.forks, repo.fork)
                project.metadata = metadata
            rescue Octokit::NotFound
                puts "Not found: #{project.name}"
            end

        end
        return projects
    end

    def checkRateLimit
        if @client.rate_limit.remaining <= 0 then
            puts "Rate limit reached, sleeping until #{@client.rate_limit.resets_at}"
            sleep(Time.parse(client.rate_limit.resets_at) - Time.now)
            # sleep a little longer to deal with potential clock sync issues (note that sleep in Ruby counts in seconds) :)
            sleep(1)  
        end
    end

end

class IDFile

    def initialize(file)
        @parsed = parseFile(file)
    end

    def getFilesForId(id)
        
    end

    def parseFile(file)
        #TODO
    end

end

inIds = ARGV[0]
outfile = ARGV[1]

puts "Using ids: #{inIds} and out: #{outfile}"
ids = inIds.split(/,/)
projects = ProjectList.new
fetcher = ProjectFetcher.new

ids.each do |id|
    puts "Starting with ID #{id}"
    # TODO find files for this ID and store in 'files'
    files.each do |file|
        puts "Fetching file #{file}"
        projects + fetcher.fetchProjectsForFile(file)
    end
end


puts "Done fetching. Sorting #{projects.count} projects."
projects.sort!

puts "Printing to #{outfile}."
projects.print_to_file(outfile)