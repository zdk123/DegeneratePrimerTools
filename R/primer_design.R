#' primer_design
#' 
#' take an imput sequence and find degernate primers.
#' into the specified output folder, place the following:
#' 
#' 1. HTML Widget of the MSA+Degenerate Primers
#' 2. The ggplot of the primer coverage
#' 3. The dataframe of the possible degenerate primers
#' 
#' @param seqs
#' @param outputfolder
#' @param aln_iters
#' @param max_degeneracies
#' @param degeprime_iterations
#' @param keep_locations
#'  
#' @import dplyr
#' @import ggplot2
#' @importFrom ape write.tree
#' @importFrom ape ladderize
#' @importFrom msaR msaR
#' @importFrom phylocanvas phylocanvas
#' @importFrom htmlwidgets saveWidget
#' @importFrom Biostrings DNAStringSet
#' @importFrom Biostrings reverseComplement
#' @importFrom Biostrings writeXStringSet
#'  
#' @export
#'  
primer_design <- function(seqs, outputfolder,
                          aln_iters=10,
                          max_degeneracies=c(1, 10, 20, 40, 100),
                          degeprime_iterations = 100,
                          keep_locations=10) {
  if (!inherits(seqs, "DNAStringSet")) {
    stop("seqs must be aDNAStringSet")
  } 
  
  DP <- degeprimer(seqs)
  DP <- DP %>% run_alignment(maxiters = aln_iters) 
  DP <- DP %>% build_tree() 
  DP <- DP %>% design_primers(
    maxdegeneracies=max_degeneracies, number_iterations=degeprime_iterations) # this can take awhile
  
  # autofind primers
  DP_positions <- DP %>% autofind_primers(keepprimers = keep_locations)
  
  # add primers to MSA
  msa      <- add_primers_to_MSA(DP, positions = DP_positions, mode = "consensus")
  msa_html <- msaR(msa,
                   alignmentHeight = nrow(DP@msa)*20,
                   leftheader = FALSE, 
                   labelid = FALSE)
  
  df <- data.frame(DP@primerdata)
  df <- df %>% filter(Pos %in% DP_positions)
  df <- df %>% mutate(RevComp= as.character(reverseComplement(DNAStringSet(PrimerSeq))))
  df <- df %>% select(Pos, PrimerSeq, RevComp, PrimerDeg, degeneracy, coverage) 
  df <- df %>% arrange(Pos)
  
  plot1 <- plot_degeprimer(DP)

  #####################################################################
  # create output folder/files
  dir.create(outputfolder, recursive = TRUE)
  
  #primer table
  write.table(df, file = paste0(outputfolder, "/primertable.txt"), 
              sep="\t", quote = FALSE, row.names = FALSE)
  
  # primer plot
  ggsave(plot1, file = paste0(outputfolder, "/primerplot.png"))
  
  # tree
  ape::write.tree(DP@phy_tree, file = paste0(outputfolder, "/tree.nw"))
  
  # interactive tree
  phycanv <- phylocanvas(ape::ladderize(DP@phy_tree))
  saveWidget(phycanv, "tree.html")
  file.rename("tree.html", paste0(outputfolder, "/tree.html"))
  
  # primer msa
  saveWidget(msa_html, "widget.html")
  file.rename("widget.html", paste0(outputfolder, "/widget.html"))
  
  # write primer msa and input sequenes
  writeXStringSet(as(DP@msa, "DNAStringSet"),  paste0(outputfolder, "/msa.fna"))
  writeXStringSet(DP@refseq,  paste0(outputfolder, "/seqs.fna"))
  
  # degeprimer object
  saveRDS(DP, file = paste0(outputfolder, "/degeprime.RDS"))
  
}
