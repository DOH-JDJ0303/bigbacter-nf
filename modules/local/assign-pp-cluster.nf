process ASSIGN_PP_CLUSTER {
    tag "${taxa}"
    label 'process_high'

    input:
    tuple val(taxa), val(sample), path(assembly), path(db)
    val timestamp

    output:
    path 'pp_results.csv',                                  emit: cluster_results
    tuple val(taxa), path('*.tar.gz', includeInputs: true), emit: new_pp_db
    path 'versions.yml',                                    emit: versions


    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    prefix         = taxa
    db_name        = db.name
    '''
    # decompress database
    db_comp="!{db_name}"
    db=${db_comp%.tar.gz}
    tar -xzvf !{db} -C ./

    #### SETTING UP FOR POPPUNK ####
    # create qfile for PopPUNK
    echo !{sample.join(',')} | tr ',' '\n' > s_col
    echo !{assembly.join(',')} | tr ',' '\n' > a_col
    paste s_col a_col -d ',' > ALL
    # exclude samples that have already been run
    old_s=$(cat */*_clusters.csv | tr ',' '\t' | cut -f 1 | tr '\n\t\r$ ' '@')
    for line in $(cat ALL)
    do
        s=$(echo ${line} | tr ',' '\t' | cut -f 1)
        if [[ "${old_s}" != *"@${s}@"*  ]]
        then
            echo ${line} | tr ',' '\t' >> qfile.txt
        fi
    done
    #### RUN POPPUNK ####
    # check for new samples (qfile is not empty)
    if [ -s qfile.txt ]
    then
        # run PopPUNK
        poppunk_assign \
        !{args} \
        --db ${db}  \
        --query qfile.txt \
        --output !{timestamp} \
        --threads !{task.cpus}
        
        # compress new database (output)
        tar -czvf !{timestamp}.tar.gz !{timestamp}
        # remove old database tar files
        rm -r ${db}*
    fi

    #### COLLECTING CLUSTER INFO ####
    # get cluster info for each sample
    echo "sample,taxa,cluster" > pp_results.csv
    for s in $(cat ALL | tr ',' '\t' | cut -f 1)
    do
        clust_file=$(ls */*_clusters.csv | grep -v "unword")
        cat ${clust_file} | tr ',' '\t' | awk '{printf($1 "\t%05d,", $2)}' | tr ',' '\n' | awk -v s=${s} -v t=!{taxa} '$1 == s {print $1,t,$2}' | tr ' ' ',' >> pp_results.csv
    done
    
    # version info
    echo "!{task.process}:\n    poppunk: $(poppunk_assign --version | cut -f 2 -d ' ' | tr -d '\n\r\t ')" > versions.yml
    '''
}
