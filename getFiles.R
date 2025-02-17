getFiles <- function(sample=NULL, task=NULL, write=TRUE) {
    if (sample == "bsocial") {
        if (task == "clock") {
            files <- dir('/ix1/adombrovski/DNPL_DataMesh/Data/BSOC/data_fmriprep/fmriprep', pattern='sub-[0-9]*$')
            idlist <- stringr::str_split(files, pattern="-") %>% unlist %>% as.numeric %>% na.omit %>% as.vector
            sub_df <- data.frame(id=rep(idlist, each=2), run=c(1,2), nifti=1)
            for (i in 1:nrow(sub_df)) {
                id <- sub_df$id[i]
                func_data <- list.files(paste0('/ix1/adombrovski/DNPL_DataMesh/Data/BSOC/data_fmriprep/fmriprep/sub-', id, '/func'))
                if (length(func_data)==0) {
                    message(paste('Subject', id, 'has no func folder.'))
                    sub_df[which(sub_df$id==id),3] <- NA
                    next
                }
                postproc_files <- func_data[grep("nfasm", func_data)]
                clock_runs <- postproc_files[grep("clock", postproc_files)]
                clock_1 <- clock_runs[which(grepl('run-1', clock_runs))]
                clock_2 <- clock_runs[which(grepl('run-2', clock_runs))]
                if (length(clock_1)==0) {
                    message(paste('Subject', id, 'is missing run 1.'))
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- NA
                } else {
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- clock_1
                }
                if (length(clock_2)==0) {
                    message(paste('Subject', id, 'is missing run 2.'))
                    sub_df[which(sub_df$run==2&sub_df$id==id),3] <- NA
                } else {
                    sub_df[which(sub_df$run==2&sub_df$id==id),3] <- clock_2
                } 
            }
        } else if (task == "trust") {
            files <- dir('/ix1/adombrovski/DNPL_DataMesh/Data/BSOC/data_fmriprep/fmriprep', pattern='sub-[0-9]*$')
            idlist <- stringr::str_split(files, pattern="-") %>% unlist %>% as.numeric %>% na.omit %>% as.vector
            sub_df <- data.frame(id=rep(idlist, each=1), run=1, nifti=1)
            for (i in 1:nrow(sub_df)) {
                id <- sub_df$id[i]
                func_data <- list.files(paste0('/ix1/adombrovski/DNPL_DataMesh/Data/BSOC/data_fmriprep/fmriprep/sub-', id, '/func'))
                if (length(func_data)==0) {
                    message(paste('Subject', id, 'has no func folder.'))
                    sub_df[which(sub_df$id==id),3] <- NA
                    next
                }
                postproc_files <- func_data[grep("nfasm", func_data)]
                trust_run <- postproc_files[grep("trust", postproc_files)]
                if (length(trust_run)==0) {
                    message(paste('Subject', id, 'is missing Trust.'))
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- NA
                } else if (length(trust_run)>1) {
                    trust_run <- trust_run[grep("MNI152NLin2009cAsym", trust_run)]
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- trust_run
                } else {
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- trust_run
                }
            }
        }
    }
    if (sample == "explore") {
        if (task == "clock") {
            files <- dir('/ix1/adombrovski/DNPL_DataMesh/Data/EXP/data_fmriprep/fmriprep', pattern='sub-[0-9]*$')
            idlist <- stringr::str_split(files, pattern="-") %>% unlist %>% as.numeric %>% na.omit %>% as.vector
            sub_df <- data.frame(id=rep(idlist, each=2), run=c(1,2), nifti=1)
            for (i in 1:nrow(sub_df)) {
                id <- sub_df$id[i]
                func_data <- list.files(paste0('/ix1/adombrovski/DNPL_DataMesh/Data/EXP/data_fmriprep/fmriprep/sub-', id, '/func'))
                if (length(func_data)==0) {
                    message(paste('Subject', id, 'has no func folder.'))
                    sub_df[which(sub_df$id==id),3] <- NA
                    next
                }
                postproc_files <- func_data[grep("nfas", func_data)]
                clock_runs <- postproc_files[grep("clock", postproc_files)]
                clock_1 <- clock_runs[which(grepl('run-1', clock_runs))]
                clock_2 <- clock_runs[which(grepl('run-2', clock_runs))]
                if (length(clock_1)==0) {
                    message(paste('Subject', id, 'is missing run 1.'))
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- NA
                } else {
                    sub_df[which(sub_df$run==1&sub_df$id==id),3] <- clock_1
                }
                if (length(clock_2)==0) {
                    message(paste('Subject', id, 'is missing run 2.'))
                    sub_df[which(sub_df$run==2&sub_df$id==id),3] <- NA
                } else {
                    sub_df[which(sub_df$run==2&sub_df$id==id),3] <- clock_2
                }
 			}
        }
    }
    if (write==T) {
        file_string <- file.path("/ix1/adombrovski/DNPL_DataMesh/Data/bea_demo/runMedusa", paste0(sample, "_", task, ".csv"))
        print(paste("Writing file CSV to:", file_string))
        write.csv(sub_df, file=file_string, row.names=F)
    }
    return(sub_df)
}   
