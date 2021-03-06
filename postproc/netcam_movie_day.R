# args: eingang / hinterhaus
# commandArgs <- function(...) "eingang"
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
if (!exists("sel_day")) sel_day <- args[2]
sel_day <- as.Date(sel_day)
library(data.table)
library(suncalc)
ffmpeg <- "/usr/bin/ffmpeg -hide_banner -loglevel panic"
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
tempTextFile <- sprintf("/tmp/vidfiles%d.txt", as.integer(Sys.time()))
seconds_per_video <- 10
speedup <- 2
video <- data.table(datei = list.files(indir, pattern="ogg"))
stopifnot(nrow(video) > 0)
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
if (camID == "eingang") video <- video[zeit > as.POSIXct('2019-01-28'),] # No audio before this date
if (camID == "bambus") video <- video[zeit > as.POSIXct('2019-01-31'),] # No audio before this date
if (camID == "hinterhaus") video <- video[zeit > as.POSIXct('2019-02-08'),] # No audio before this date
video[, stunde := as.numeric(format(zeit, "%H")) + as.numeric(format(zeit, "%M")) / 60]
video[, sunrise := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunrise]
video[, sunrise := as.numeric(format(sunrise, "%H")) + as.numeric(format(sunrise, "%M")) / 60]
video[, sunsetStart := getSunlightTimes(date = as.Date(zeit), lat = 46.93, lon = 7.415, tz = "CET")$sunsetStart]
video[, sunsetStart := as.numeric(format(sunsetStart, "%H")) + as.numeric(format(sunsetStart, "%M")) / 60]
video[, tag := stunde > sunrise & stunde < sunsetStart]
video[tag==TRUE, id := 1:nrow(video[tag == TRUE,])]
video[tag==TRUE, wahl := as.Date(zeit) == sel_day]
video[is.na(wahl), "wahl"] <- FALSE
print(table(video$tag, video$wahl, dnn=c("tag", "wahl")))
stopifnot(nrow(video[wahl==TRUE,]) > 0)

for (v in video[wahl==TRUE, datei]) {
	cmd <- sprintf("%s -y -err_detect ignore_err -i %s/%s -to 00:00:%02d -c copy /tmp/%s", ffmpeg, indir, v, seconds_per_video, v)
	writeLines(cmd)
	system(cmd)
}

mergefiles <- sprintf("file '/tmp/%s'", video[wahl==TRUE, datei])
write(mergefiles, file=tempTextFile)
outfile <- sprintf("%s_%s.ogg", camID, sel_day)
if (speedup == 1) cmd <- sprintf('%s -y -f concat -safe 0 -i %s -qscale:v 7 %s', ffmpeg, tempTextFile, outfile)
if (speedup == 2) cmd <- sprintf('%s -y -f concat -safe 0 -i %s -filter:v "setpts=0.5*PTS" -filter:a "atempo=2.0" -qscale:v 7 %s', ffmpeg, tempTextFile, outfile)
if (speedup == 4) cmd <- sprintf('%s -y -f concat -safe 0 -i %s -filter:v "setpts=0.25*PTS" -filter:a "atempo=2.0,atempo=2.0" -qscale:v 7 %s', ffmpeg, tempTextFile, outfile)
writeLines(cmd)
system(cmd)
