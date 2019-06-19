# args: eingang / hinterhaus
args <- commandArgs(trailingOnly=TRUE)
indir <- args[1]
library(data.table)
library(suncalc)
writeLines(sprintf("Movie directory: %s", indir))
tempTextFile <- "/tmp/vidfiles.txt"
video <- data.table(datei = list.files(indir, pattern="ogg"))
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
video[, stunde := as.numeric(format(zeit, "%H")) + as.numeric(format(zeit, "%M")) / 60]
video[, sunrise := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunrise]
video[, sunrise := as.numeric(format(sunrise, "%H")) + as.numeric(format(sunrise, "%M")) / 60]
video[, sunsetStart := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunsetStart]
video[, sunsetStart := as.numeric(format(sunsetStart, "%H")) + as.numeric(format(sunsetStart, "%M")) / 60]
video[, tag := stunde > sunrise & stunde < sunsetStart]
print(table(video$tag, dnn=c("tag")))
mergefiles <- sprintf("file '%s/%s'", indir, video[tag==TRUE, datei])
write(mergefiles, file=tempTextFile)
outfile <- sprintf("merged_%s.mp4", basename(indir))
writeLines(outfile)
cmd <- sprintf(
	'ffmpeg -y -hide_banner -loglevel panic -f concat -safe 0 -i %s -filter:v "setpts=0.25*PTS" -filter:a "atempo=2.0,atempo=2.0" %s', 
	tempTextFile, outfile
)
system(cmd)
