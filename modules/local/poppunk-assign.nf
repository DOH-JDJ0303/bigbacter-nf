process POPPUNK_ASSIGN {
    tag "${taxa}"
    label 'process_high'

    input:
    tuple val(taxa), val(sample), path(assembly), path(db)
    val timestamp

    output:
    tuple val(taxa), path('clusters.csv'),                  emit: cluster_results
    tuple val(taxa), path('merged_clusters.csv'),           emit: merged_clusters
    tuple val(taxa), path('pp-core-acc-dist.txt.gz'),       emit: core_acc_dist
    tuple val(taxa), path('pp-jaccard-dist.txt.gz'),        emit: jaccard_dist
    tuple val(taxa), path('*.tar.gz', includeInputs: true), emit: new_pp_db
    path 'versions.yml',                                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    prefix         = "${timestamp}-${taxa}"
    db_name        = db.name
    '''
    # decompress database
    db_comp="!{db_name}"
    db=${db_comp%.tar.gz}
    tar -xzvf !{db} -C ./

    #### CREATE QFILE ####
    echo !{sample.join(',')} | tr ',' '\n' > s_col
    echo !{assembly.join(',')} | tr ',' '\n' > a_col
    paste s_col a_col > qfile.txt

    #### ASSIGN CLUSTERS ####
    # run PopPUNK
    echo -e "\nAssigning clusters with PopPUNK.\n"
    poppunk_assign \
        !{args} \
        --db ${db}  \
        --query qfile.txt \
        --output !{timestamp} \
        --threads !{task.cpus} \
        --write-reference

    # compress new database (output) & remove old database
    tar -czvf !{timestamp}.tar.gz !{timestamp} && rm -r ${db}*

    #### CALCULATE DISTANCES ####
    # core & accessory distances
    sketchlib query dist --cpus !{task.cpus} */*[^refs].h5 | gzip > pp-core-acc-dist.txt.gz
    sketchlib query jaccard --cpus !{task.cpus} */*[^refs].h5 | gzip > pp-jaccard-dist.txt.gz

    #### RENAME CLUSTER RESULTS ####
    cp */*[^_unword]_clusters.csv clusters.csv
    
    #### CREATE LIST OF MERGED CLUSTERS #### 
    echo "taxa,merged_cluster,cluster" > merged_clusters.csv
    for m in $(cat clusters.csv | cut -f 2 -d ',' | grep '_' | sort | uniq)
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
