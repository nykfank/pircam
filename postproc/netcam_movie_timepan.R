# args: eingang / hinterhaus
# commandArgs <- function(...) "eingang"
args <- commandArgs(trailingOnly=TRUE)
if (!exists("camID")) camID <- args[1]
library(data.table)
library(suncalc)
ffmpeg <- "/usr/bin/ffmpeg -hide_banner -loglevel panic"
indir <- sprintf("/mnt/big/nick/cams/%s", camID)
writeLines(sprintf("Movie directory: %s", indir))
outfile <- sprintf("timespan_%s.ogg", basename(indir))
tempTextFile <- sprintf("/tmp/vidfiles%d.txt", as.integer(Sys.time()))
sampleSize <- 60
seconds_per_video <- 3
speedup_factor <- 2
video <- data.table(datei = list.files(indir, pattern="mp4|ogg"))
stopifnot(nrow(video) > 0)
video[, zeit := as.POSIXct(sub("netcam", "", datei), tz="", "%Y%m%d_%H%M%S")]
video[, stunde := as.numeric(format(zeit, "%H")) + as.numeric(format(zeit, "%M")) / 60]

# Select timespan:
video[, timespan := stunde > 3 & stunde < 7]

video[timespan==TRUE, id := 1:nrow(video[timespan == TRUE,])]
video[timespan==TRUE, wahl := id %in% sample(1:nrow(video[timespan == TRUE,]), sampleSize)]
video[is.na(wahl), "wahl"] <- FALSE
print(table(video$timespan, video$wahl, dnn=c("timespan", "wahl")))

# Same as netcam_movie_sampler_frames.R

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
in_fps <- min(video$fps, na.rm = TRUE)
out_fps <- in_fps * speedup_factor
video$fps_ratio <- as.numeric(video$fps / in_fps)

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
writeLines(cmd)
system(cmd)

framefiles <- list.files(framedir, full.names = TRUE)
for (i in 1:length(framefiles)) {
	file.rename(framefiles[i], sprintf("%s/frame%05d.png", framedir, i))
}

audiofiles <- list.files(audiodir, full.names = TRUE)
audiofiles_selected <- audiofiles[1:length(audiofiles) %% (floor(out_fps / in_fps)) == 0]
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
