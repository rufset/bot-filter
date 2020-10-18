class BotBag

    attr_accessor :bots    

    def initialize
        self.bots = []
    end

    def <<(bots)
        self.bots+= bots
    end

    def sort!
        self.bots.sort!{|a,b| b.project_count <=> a.project_count}
    end

    def bots_count
        self.bots.size
    end

    def print_overview_file(file)
        File.open(file, 'w') do |f|
            self.bots.each do |bot|
                f.write(bot.to_string)
            end
        end
    end

    def print_project_lists(dir)
        Dir.mkdir(dir) unless Dir.exist?(dir)
        self.bots.each do |bot|
            File.open("#{dir}/#{bot.name}.txt", 'w') do |f|
                f.write(bot.to_string(summary=false))
            end
        end
    end
end

class Bot

    attr_accessor :name
    attr_accessor :projects

    def initialize(name)
        self.name = name
        self.projects = []
    end

    def <<(projects)
        projects.each do |project|
            self.projects << project unless self.projects.include?(project)
        end
    end

    def project_count
        self.projects.size
    end

    def to_string(summary=true)
        if summary then
            "#{self.name}: #{self.project_count}\n"
        else
            str = "#{self.name}:\n"
            self.projects.each{|p| str+= "#{p}\n" }
            str+= "\n"
            return str
        end
    end

end

def load_file(file)

    bots = {}
    counter = 0

    File.open(file, 'r').each_line do |line|

        # debug
        # if counter > 200000 then
        #     break
        # end

        counter += 1
        data = line.split(/;/)
        author = data[0].match(/<(.*)>/).captures[0]
        projects = data[5].split(/,/)
        projects.map! do |project|
            project.split(/\_/)[0]
        end

        bots[author] = Bot.new(author) unless bots.key?(author)
        bots[author] << projects

        puts "Handled #{counter} lines" if counter % 1000 == 0
    end

    botbag = BotBag.new
    botbag << bots.values
    botbag.sort!

    puts "Sorted #{botbag.bots_count} bots"

    return botbag

end


# main method
bots = load_file(ARGV[0])
bots.print_overview_file('overview.txt')
bots.print_project_lists('projects')