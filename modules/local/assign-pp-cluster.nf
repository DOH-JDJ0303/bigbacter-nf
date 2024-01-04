process ASSIGN_PP_CLUSTER {
    tag "${taxa}"
    label 'process_high'

    input:
    tuple val(taxa), val(sample), path(assembly), path(db)
    val timestamp

    output:
    path 'pp_results.csv',                                  emit: cluster_results
    path 'merged_clusters.csv',                             emit: merged_clusters
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
    old_s=$(cat */*_clusters.csv | tr ',' '\t' | cut -f 1 | tr '\n\t\r$ ' '@' | sed 's/^/@/g')
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

        # compress new database (output) & remove old database
        tar -czvf !{timestamp}.tar.gz !{timestamp} && rm -r ${db}*
    fi

    #### RENAME RESULTS ####
    cp $(ls */*_clusters.csv | grep -v "unword") pp_results.csv

    #### SPLIT MERGED CLUSTERS ####
    echo "taxa,merged_cluster,cluster" > merged_clusters.csv
    for m in $(cat pp_results.csv | cut -f 2 -d ',' | grep '_' | sort | uniq)
    do
        for c in $(echo ${m} | tr '_' ' ')
        do
            echo "!{taxa},${m},$(printf "%05d" ${c})" >> merged_clusters.csv
        done
    done
    
    # version info
    echo "!{task.process}:\n    poppunk: $(poppunk_assign --version | cut -f 2 -d ' ' | tr -d '\n\r\t ')" > versions.yml
    '''
}
