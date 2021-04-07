require 'octokit'
require 'time'

class ProjectList
    include Enumerable

    attr_accessor :projects

    def initialize
        @projects = []
    end

    def self.parse(dir)

        list = ProjectList.new
        Dir.foreach(dir) do |projects_file|
            qf = dir+'/'+projects_file
            next if File.directory?(qf)  
            File.open(qf, 'r').each_line do |l|
                org, p = l.split(/\//)
                next unless p   # if the splitting didn't work let's just skip this line
                p.strip!
                project = Project.new(org, p)
                list << project
            end
        end
        return list
    end

    def each(&block)
        @projects.each(&block)
    end

    def <<(project)
        @projects << project
        clearDuplicates
    end

    def sort!
        cleanUnfetched
        @projects.sort! { |a,b| b.metadata.total_issues <=> a.metadata.total_issues }
    end

    def print_to_file(file)
        header = 'project;total_issues'
        File.open(file, 'w') do |f|
            f.puts header
            @projects.each{ |p| f.puts p.to_s }
        end
    end

    def cleanUnfetched
       @projects.filter!{ |p| p.metadata != nil } 
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
        "#{name};#{@metadata.total_issues}"
    end

end

class ProjectMetadata

    attr_accessor :total_issues

    def initialize(total_issues)
        @total_issues = total_issues
    end

end

class ProjectFetcher

    def initialize(key)
        @client = Octokit::Client.new(:access_token => key)
    end

    def fetchProjectsForDir(dir)
        projects = ProjectList.parse(dir)
        projects.each do |project|
            
            checkRateLimit

            # fetch repo
            puts "Fetching #{project.name}"
            begin
                some_issues = @client.list_issues(project.name, options = {:state => 'all'})
                total_issues = some_issues[0][:number]  # 'number' is a running number, and the first issue returned is the last created ...
                metadata = ProjectMetadata.new(total_issues)
                project.metadata = metadata
            rescue Octokit::TooManyRequests
                checkRateLimit
            rescue Octokit::NotFound
                puts "Not found: #{project.name}"
            rescue Octokit::InvalidRepository
                puts "Invalid repo: #{project.name}"
            rescue Octokit::RepositoryUnavailable
                puts "Unavailable repo: #{project.name}"
            rescue Octokit::UnavailableForLegalReasons
                puts "DMCA takedown: #{project.name}"
            rescue Octokit::Unauthorized
                puts "Access denied: #{project.name}"
            end

        end
        return projects
    end

    def checkRateLimit
        if @client.rate_limit.remaining <= 0 then
            puts "Rate limit reached, sleeping until #{@client.rate_limit.resets_at.to_s}"
            sleepTime = @client.rate_limit.resets_at - Time.now + 60
            sleep(sleepTime) unless sleepTime <= 0
        end
    end

end

$stdout.sync = true # disable output buffering, required for non-interactive consoles

indir = ARGV[0]
outfile = ARGV[1]
keyfile = ARGV[2]

key = File.read(keyfile)

puts "Using in: #{indir} and out: #{outfile}"
fetcher = ProjectFetcher.new(key)
puts "Fetching for dir #{indir}"
projects = fetcher.fetchProjectsForDir(indir)

puts "Done fetching. Sorting #{projects.count} projects."
projects.sort!

puts "Printing to #{outfile}."
projects.print_to_file(outfile)
