process ASSIGN_PP_CLUSTER {

    input:
    tuple path(db), val(samples), val(taxa), path(assemblies)
    val timestamp

    output:
    path 'pp_results.csv',                                emit: cluster_results
    tuple val(taxa_name), path('*.tar.gz'), path('CACHE'), emit: new_pp_db
    path 'cluster_status.csv',                            emit: cluster_status
    path 'sample_status.csv',                             emit: sample_status


    when:
    task.ext.when == null || task.ext.when

    shell:
    args           = task.ext.args ?: ''
    assembly_names = assemblies.name
    taxa_name      = taxa[0]
    prefix         = taxa[0]
    db_name        = db.name
    '''
    # decompress database
    db_comp="!{db_name}"
    db=${db_comp%.tar.gz}
    tar -xzvf !{db} -C ./
    rm !{db}

    #### SETTING UP FOR POPPUNK ####
    # create qfile for PopPUNK
    echo !{samples} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    paste s_col a_col > qfile.txt

    # create cache file for the new database
    echo !{timestamp} > CACHE

    #### RUN POPPUNK ####
    poppunk_assign \
       !{args} \
       --db ${db}  \
       --query qfile.txt \
       --output !{timestamp}

    #### COLLECTING CLUSTER INFO ####
    # get cluster info for each sample
    samp=$(cat qfile.txt | cut -f 1)
    echo "sample,cluster,taxa_cluster" > pp_results.csv
    for s in ${samp}
    do
        cat !{timestamp}/!{timestamp}_clusters.csv | tr ',' '\t' | awk '{printf($1 "\t%05d,", $2)}' | tr ',' '\n' | awk -v s=${s} -v t=!{taxa_name} '$1 == s {print $1,$2,t"_"$2}' | tr ' ' ',' >> pp_results.csv
    done

    # define status for each cluster
    echo "taxa_cluster,status" > cluster_status.csv
    clusts=$(cat pp_results.csv | tr ',' '\t' | cut -f 2 | grep -v "cluster" | sort | uniq)
    for c in ${clusts}
    do
        status=$(cat ${db}/${db}_clusters.csv | tr ',' '\t' | grep -v "Cluster" | awk -v c=${c} '$2 == c {print "old"}' | sort | uniq)
        if [[ "${status}" == "old" ]]
        then
            echo "!{taxa_name}_${c},old" >> cluster_status.csv
        else
            echo "!{taxa_name}_${c},new" >> cluster_status.csv
        fi
    done
    # create table of samples and their asociated status
    echo "sample,status" > sample_status.csv
    samp=$(cat pp_results.csv | tail -n +2)
    for line in ${samp}
    do
        sample=$(echo ${line} | tr ',' '\t' | cut -f 1)
        taxa_cluster=$(echo ${line} | tr ',' '\t' | cut -f 3)
        status=$(cat cluster_status.csv | tr ',' '\t' | awk -v tc=${taxa_cluster} '$1 == tc {print $2}')
        echo "${sample},${status}" >> sample_status.csv
    done

    # compress new database
    tar -czvf !{timestamp}.tar.gz !{timestamp}

    #### VERSION INFO ####
    echo "hello" > versions.yml
    '''
}
