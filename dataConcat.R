dataConcat <- function(dir=NULL, sample=NULL, task=NULL, mask=NULL) {
    interp_data <- file.path(dir, task, sample, mask, "interpolated")
    alignments <- list.dirs(interp_data)[2:length(list.dirs(interp_data))]
    for (i in 1:length(alignments)) {
        curr_dir <- alignments[i]
        alignment_string <- str_split(curr_dir, pattern="/")[[1]][13]
        setwd(curr_dir)
        print(paste("Concatenating data in the following folder:", curr_dir))
        filelist <- list.files(curr_dir)
        x <- str_split(filelist, pattern="_interpolated")
        names(filelist) <- sapply(x, head, 1)
        aligned_data <- purrr::map_dfr(filelist, data.table::fread, .id="id")
        aligned_data <- aligned_data %>%
            mutate(run=str_extract(id, pattern="run\\d"), subj=str_extract(id, pattern="\\d{5,}")) %>% 
            select(-id) %>% 
            select(id=subj, run, atlas_value, trial, evt_time, decon_mean, decon_median, decon_sd)
        out_dir <- file.path(dir, task, sample, mask)
        print(paste("Writing data file to the following folder:", out_dir))
        data.table::fwrite(aligned_data, file.path(out_dir, paste0(alignment_string, "_", mask, ".csv.gz")))
    }
}