# args: eingang / hinterhaus
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
library(data.table)
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
tempTextFile <- "/tmp/vidfiles.txt"
sampleSize <- 50
video <- data.table(datei = list.files(indir, pattern="ogg"))
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
video[, stunde := as.numeric(format(zeit, "%H"))]
video[, stunde := stunde + as.numeric(format(zeit, "%M")) / 60]
video[, tag := stunde > 8 & stunde < 16.5]
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
