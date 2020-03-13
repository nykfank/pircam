conditions <- factor(c(
	"PAO0", "PAO0", "PAO0", "PAO12", "PAO12", "PAO12", "PAO24", "PAO24", "PAO24", 
	"PAO36", "PAO36", "PAO36",	"PAO48", "PAO48", "PAO48", 
	"WT0", "WT0", "WT0", "WT12", "WT12", "WT12", "WT24", "WT24", "WT24", 
	"WT36", "WT36", "WT36", "WT48", "WT48", "WT48"
))

samples <- paste(conditions, rep(1:3, 10), sep="_")

load_rsem_results <- function(sample) {
	writeLines(sample)
	filename <- paste(sample, "genes.results", sep=".")
	x <- read.table(filename, header=TRUE)
	x <- x[,c("gene_id", "TPM")]
	colnames(x)[2] <- sample
	x
}
writeLines("Loading samples...")
reslist <- lapply(samples, load_rsem_results)
writeLines("Merging samples...")
resmatrix <- Reduce(function(...) merge(...), reslist)

# Find differentially expressed genes at any timepoint
library(EBSeq)
degenlist <- list()
for (tp in seq(from=0, to=48, by=12)) {
	conditions_ebseq <- factor(paste(c(rep("PAO", 3), rep("WT", 3)), tp, sep=""))
	samples_ebseq <- paste(conditions_ebseq, rep(1:3, 2), sep="_")
	GeneMat <- as.matrix(resmatrix[,samples_ebseq])
	rownames(GeneMat) <- resmatrix$gene_id
	Sizes <- MedianNorm(GeneMat)
	writeLines("Running EBSeq...")
	EBOut <- EBTest(Data=GeneMat, Conditions=conditions_ebseq, sizeFactors=Sizes, maxround=5)
	de_genes <- names(EBOut$PPDE)[EBOut$PPDE > 0.9]
	writeLines(sprintf("Timepoint %d, DE genes: %d", tp, length(de_genes)))
	degenlist[[as.character(tp)]] <- de_genes
}

de_genes <- unique(unlist(degenlist))
writeLines(sprintf("Total DE genes: %d", length(de_genes)))

resmatrix1pao <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("PAO", colnames(resmatrix)) & grepl("_1", colnames(resmatrix))])]
resmatrix1wt <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("WT", colnames(resmatrix)) & grepl("_1", colnames(resmatrix))])]
resmatrix2pao <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("PAO", colnames(resmatrix)) & grepl("_2", colnames(resmatrix))])]
resmatrix2wt <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("WT", colnames(resmatrix)) & grepl("_2", colnames(resmatrix))])]
resmatrix3pao <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("PAO", colnames(resmatrix)) & grepl("_3", colnames(resmatrix))])]
resmatrix3wt <- resmatrix[resmatrix$gene_id %in% de_genes, c("gene_id", colnames(resmatrix)[grepl("WT", colnames(resmatrix)) & grepl("_3", colnames(resmatrix))])]
colnames(resmatrix1pao) <- sub("_1", "", colnames(resmatrix1pao))
colnames(resmatrix2pao) <- sub("_2", "", colnames(resmatrix2pao))
colnames(resmatrix3pao) <- sub("_3", "", colnames(resmatrix3pao))
colnames(resmatrix1wt) <- sub("_1", "", colnames(resmatrix1wt))
colnames(resmatrix2wt) <- sub("_2", "", colnames(resmatrix2wt))
colnames(resmatrix3wt) <- sub("_3", "", colnames(resmatrix3wt))
colnames(resmatrix1pao) <- sub("PAO", "", colnames(resmatrix1pao))
colnames(resmatrix2pao) <- sub("PAO", "", colnames(resmatrix2pao))
colnames(resmatrix3pao) <- sub("PAO", "", colnames(resmatrix3pao))
colnames(resmatrix1wt) <- sub("WT", "", colnames(resmatrix1wt))
colnames(resmatrix2wt) <- sub("WT", "", colnames(resmatrix2wt))
colnames(resmatrix3wt) <- sub("WT", "", colnames(resmatrix3wt))

writeLines("Writing TSV files...")
write.table(resmatrix, file="timecourse_matrix.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix1pao, file="timecourse_PAO_matrix1.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix2pao, file="timecourse_PAO_matrix2.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix3pao, file="timecourse_PAO_matrix3.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix1wt, file="timecourse_WT_matrix1.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix2wt, file="timecourse_WT_matrix2.tsv", sep="\t", quote=FALSE, row.names=FALSE)
write.table(resmatrix3wt, file="timecourse_WT_matrix3.tsv", sep="\t", quote=FALSE, row.names=FALSE)
