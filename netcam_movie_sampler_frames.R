# args: eingang / hinterhaus
# commandArgs <- function(...) "eingang"
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
library(data.table)
library(suncalc)
ffmpeg <- "/usr/bin/ffmpeg -hide_banner -loglevel panic"
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
outfile <- sprintf("sampled_%s.ogg", basename(indir))
tempTextFile <- sprintf("/tmp/vidfiles%d.txt", as.integer(Sys.time()))
sampleSize <- 30
seconds_per_video <- 3
in_fps <- 4
out_fps <- 16
video <- data.table(datei = list.files(indir, pattern="mp4|ogg"))
stopifnot(nrow(video) > 0)
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
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

# Extract FPS for selected videos
for (v in video[wahl==TRUE, datei]) {
	cmd <- sprintf("ffprobe %s/%s 2>&1", indir, v)
	writeLines(cmd)
	r <- system(cmd, intern=TRUE)
	tbrtext <- regmatches(r, regexpr("\\d+ tbr", r))
	fpstext <- regmatches(r, regexpr("\\d+ fps", r))
	fps <- as.integer(sub(" fps", "", fpstext))
	tbr <- as.integer(sub(" tbr", "", tbrtext))
	if (length(tbr) > 0) video[datei == v, "fps"] <- tbr else video[datei == v, "fps"] <- fps
}
video$fps_ratio <- as.numeric(video$fps / min(video$fps, na.rm = TRUE))

framedir <- sprintf("/tmp/frames_%d", as.integer(Sys.time()))
audiodir <- sprintf("/tmp/audio_%d", as.integer(Sys.time()))
dir.create(framedir)
dir.create(audiodir)
for (v in video[wahl==TRUE, datei]) {
	vbase <- tools::file_path_sans_ext(v)
	cmd <- sprintf("%s -i %s/%s -to 00:00:%02d %s/%s_%%05d.png", ffmpeg, indir, v, seconds_per_video, framedir, vbase)
	writeLines(cmd)
	system(cmd)
	cmd <- sprintf("%s -i %s/%s -to 00:00:%02d -vn -acodec copy %s/%s.mp4",	ffmpeg, indir, v, seconds_per_video, audiodir, vbase)
	writeLines(cmd)
	system(cmd)
	if (video[datei == v, fps_ratio] > 1) {
		framefiles <- list.files(framedir, full.names = TRUE, pattern=vbase)
		for (i in 1:length(framefiles)) {
			if (i %% video[datei == v, fps_ratio] > 0) unlink(framefiles[i])
		}
	}
}

cmd <- sprintf("seq_check.py %s", framedir)
#writeLines(cmd)
#system(cmd)

framefiles <- list.files(framedir, full.names = TRUE)
for (i in 1:length(framefiles)) {
	file.rename(framefiles[i], sprintf("%s/frame%05d.png", framedir, i))
}

audiofiles <- list.files(audiodir, full.names = TRUE)
audiofiles_selected <- audiofiles[1:length(audiofiles) %% (floor(out_fps / in_fps) - 1) == 0]
mergefiles <- sprintf("file '%s'", audiofiles_selected)
tempTextFile <- sprintf("/tmp/vidfiles%d.txt", as.integer(Sys.time()))
write(mergefiles, file=tempTextFile)
merged_audio_file <- sprintf("/tmp/audio%d.mp4", as.integer(Sys.time()))

cmd <- sprintf("%s -f concat -safe 0 -i %s %s", ffmpeg, tempTextFile, merged_audio_file)
writeLines(cmd)
system(cmd)

cmd <- sprintf("%s -y -framerate %d -i %s/frame%%05d.png -i %s -codec:v libtheora -qscale:v 7 %s",
	ffmpeg, out_fps, framedir, merged_audio_file, outfile)
writeLines(cmd)
system(cmd)
