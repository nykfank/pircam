logfile <- "/var/log/pircam_log.txt"
outfile <- "/tmp/pircam_plot.png"

library(ggplot2)
library(ggthemes) # For theme_economist

# Parse logfile
event <- readLines(logfile)
event <- event[grepl("Motion, video", event)]
event <- as.data.frame(t(as.data.frame(strsplit(event, ": "))))
event$V3 <- NULL
rownames(event) <- NULL
colnames(event) <- c("timestamp", "camera")
event$timestamp <- strptime(event$timestamp, "%Y-%m-%d %H:%M:%S")

# Prepare date
event$date <- as.Date(event$timestamp)
event$hour <- as.integer(strftime(event$timestamp, "%H"))
event <- event[event$date > max(event$date) - 7,] # Only plot last 6 days
event$id <- 1:nrow(event)
evag <- aggregate(id ~ date + hour + camera, data=event, FUN=length)

# Create plot
p <- ggplot(data = evag, aes(hour, id, fill=camera)) + 
stat_summary(fun.y = sum, geom = "bar") + 
scale_x_continuous(breaks = 0:23) +
facet_grid(date~.) +
theme_economist() +
labs(x=NULL, y=NULL) +
theme(axis.text=element_text(size=18), axis.title=element_text(size=18), strip.text.y=element_text(size=24)) +
guides(fill=guide_legend(title=NULL))

# Export plot as PNG
png(filename=outfile, width = 1800, height = 920)
print(p)
dev.off()

# Upload to webserver
system(sprintf("rsync %s katz:/home/www/", outfile))
