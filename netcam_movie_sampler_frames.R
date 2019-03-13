# args: eingang / hinterhaus
# commandArgs <- function(...) "eingang"
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
library(data.table)
library(suncalc)
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
outfile <- sprintf("sampled_%s.ogg", basename(indir))
tempTextFile <- sprintf("/tmp/vidfiles%d.txt", as.integer(Sys.time()))
sampleSize <- 30
seconds_per_video <- 3
in_fps <- 4
out_fps <- 16
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
video[tag==TRUE, wahl := id %in% sample(1:nrow(video[tag == TRUE,]), sampleSize)]
video[is.na(wahl), "wahl"] <- FALSE
print(table(video$tag, video$wahl, dnn=c("tag", "wahl")))
framedir <- sprintf("/tmp/frames_%d", as.integer(Sys.time()))
audiodir <- sprintf("/tmp/audio_%d", as.integer(Sys.time()))
dir.create(framedir)
dir.create(audiodir)
for (v in video[wahl==TRUE, datei]) {
	cmd <- sprintf("ffmpeg -hide_banner -loglevel panic -i %s/%s -to 00:00:%02d %s/%s_%%05d.png",
	indir, v, seconds_per_video, framedir, tools::file_path_sans_ext(v))
	writeLines(cmd)
	system(cmd)
	cmd <- sprintf("ffmpeg -hide_banner -loglevel panic -i %s/%s -to 00:00:%02d -vn -acodec copy %s/%s.mp4",
	indir, v, seconds_per_video, audiodir, tools::file_path_sans_ext(v))
	writeLines(cmd)
	system(cmd)
}

cmd <- sprintf("seq_check.py %s", framedir)
writeLines(cmd)
system(cmd)

framefiles <- list.files(framedir, full.names = TRUE)
for (i in 1:length(framefiles)) {
	file.rename(framefiles[i], sprintf("%s/frame%05d.png", framedir, i))
}

audiofiles <- list.files(audiodir, full.names = TRUE)
for (i in 1:length(audiofiles)) {
	if (i %% floor(out_fps / in_fps) == 0) {
		file.rename(audiofiles[i], sprintf("%s/audio%05d.png", audiodir, i))
	} else {
		unlink(audiofiles[i])
	}
}

cmd <- sprintf("ffmpeg -hide_banner -loglevel panic -y -framerate %d -i %s/frame%%05d.png -i %s/audio%%05d.png -codec:v libtheora -qscale:v 7 %s",
	out_fps, framedir, audiodir, outfile)
writeLines(cmd)
system(cmd)
