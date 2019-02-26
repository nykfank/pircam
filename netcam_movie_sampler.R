# args: eingang / hinterhaus
# commandArgs <- function(...) "eingang"
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
library(data.table)
library(suncalc)
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
tempTextFile <- "/tmp/vidfiles.txt"
sampleSize <- 50
video <- data.table(datei = list.files(indir, pattern="ogg"))
stopifnot(nrow(video) > 0)
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
video[, stunde := as.numeric(format(zeit, "%H")) + as.numeric(format(zeit, "%M")) / 60]
video[, sunrise := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunrise]
video[, sunrise := as.numeric(format(sunrise, "%H")) + as.numeric(format(sunrise, "%M")) / 60]
video[, sunsetStart := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunsetStart]
video[, sunsetStart := as.numeric(format(sunsetStart, "%H")) + as.numeric(format(sunsetStart, "%M")) / 60]
video[, tag := stunde > sunrise & stunde < sunsetStart]
video[tag==TRUE, id := 1:nrow(video[tag==TRUE,])]
video[tag==TRUE, wahl := id %in% sample(1:nrow(video[tag==TRUE,]), sampleSize)]
video[is.na(wahl), "wahl"] <- FALSE
print(table(video$tag, video$wahl, dnn=c("tag", "wahl")))

mergefiles <- sprintf("file '%s/%s'", indir, video[wahl==TRUE, datei])
write(mergefiles, file=tempTextFile)
outfile <- sprintf("%s%d.mp4", camID, as.integer(Sys.time()))
cmd <- sprintf(
	'ffmpeg -hide_banner -loglevel panic -f concat -safe 0 -i %s -filter:v "setpts=0.25*PTS" -filter:a "atempo=2.0,atempo=2.0" %s', 
	tempTextFile, outfile
)
system(cmd)
writeLines(outfile)

# TODO: use mediainfo filaname.ogg to get length / compression ratio