logfile <- "/var/log/pircam_log.txt"
outfile <- "/tmp/pircam_plot.png"
outfile_wide <- "/tmp/pircam_plot_wide.png"

library(ggplot2)
library(ggthemes) # For theme
#library(scales) # for solarized_pal
#colvec <- solarized_pal()(3)

# Parse logfile
event <- readLines(logfile)
event <- event[grepl("Motion, video", event)]
event <- as.data.frame(t(as.data.frame(strsplit(event, ": "))))
event$V3 <- NULL
rownames(event) <- NULL
colnames(event) <- c("timestamp", "camera")
event$timestamp <- strptime(event$timestamp, "%Y-%m-%d %H:%M:%S")

# Prepare data
event$date <- as.Date(event$timestamp)
event$hour <- as.integer(strftime(event$timestamp, "%H"))
event <- event[event$date > max(event$date) - 7,] # Only plot last 6 days
event$id <- 1:nrow(event)
evag <- aggregate(id ~ date + hour + camera, data=event, FUN=length)
evag$day <- factor(as.character(evag$date), levels=sort(unique(as.character(evag$date)), decreasing=TRUE))
evag$id <- log10(evag$id + 1)

# Create plot
p <- ggplot(data = evag, aes(hour, id)) + 
geom_bar(aes(fill=camera), stat="identity") +
scale_x_continuous(breaks = 0:23) +
scale_fill_solarized() +
facet_grid(day ~ .) +
theme_solarized_2(light=FALSE) +
labs(x=NULL, y=NULL) +
guides(fill=guide_legend(title=NULL)) +
#geom_text(label = levels(evag$camera), x = 4, y = 1:3, colour=colvec) +
theme(
	axis.text=element_text(size=28), 
	axis.title=element_text(size=32), 
	strip.text.y=element_text(size=32), 
	legend.text=element_text(size=20),
	legend.position = "bottom"
	)

# Export plot as PNG
png(filename=outfile, width=1440, height=2560) # Optimal for mobile
print(p)
dev.off()
png(filename=outfile_wide, width=1280, height=720) # Optimal for laptop
print(p)
dev.off()

# Upload to webserver
system(sprintf("rsync %s katz:/home/www/", outfile))
system(sprintf("rsync %s katz:/home/www/", outfile_wide))
