require 'rufus-scheduler'

i = 0
scheduler = Rufus::Scheduler.start_new 
scheduler.every("1m") do
	puts i += 1
end	
while true
end
