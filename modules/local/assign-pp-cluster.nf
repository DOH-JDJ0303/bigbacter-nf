process ASSIGN_PP_CLUSTER {

    input:
    tuple val(taxa), val(sample), path(assembly), path(db)
    val timestamp

    output:
    path 'pp_results.csv',                  emit: cluster_results
    tuple val(taxa), path('*.tar.gz'), emit: new_pp_db


    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    assembly_names = assembly.name
    prefix         = taxa
    db_name        = db.name
    '''
    # decompress database
    db_comp="!{db_name}"
    db=${db_comp%.tar.gz}
    tar -xzvf !{db} -C ./
    rm !{db}

    #### SETTING UP FOR POPPUNK ####
    # create qfile for PopPUNK
    echo !{sample} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
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
    poppunk_assign \
       !{args} \
       --db ${db}  \
       --query qfile.txt \
       --output !{timestamp}

    #### COLLECTING CLUSTER INFO ####
    # get cluster info for each sample
    echo "sample,taxa,cluster" > pp_results.csv
    for s in $(cat ALL | tr ',' '\t' | cut -f 1)
    do
        cat !{timestamp}/!{timestamp}_clusters.csv | tr ',' '\t' | awk '{printf($1 "\t%05d,", $2)}' | tr ',' '\n' | awk -v s=${s} -v t=!{taxa} '$1 == s {print $1,t,$2}' | tr ' ' ',' >> pp_results.csv
    done

    # compress new database
    tar -czvf !{timestamp}.tar.gz !{timestamp}

    #### VERSION INFO ####
    echo "hello" > versions.yml
    '''
}
