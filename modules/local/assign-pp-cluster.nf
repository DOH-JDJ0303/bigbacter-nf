process ASSIGN_PP_CLUSTER {
    container 'staphb/poppunk:2.6.0'

    input:
    tuple path(db), val(samples), val(taxa), path(assemblies)
    val new_db

    output:
    path 'pp_results.csv', emit: cluster_results
    tuple path(new_db), path('CACHE'), val(taxa_name), emit: new_pp_db
    path 'cluster_status.csv', emit: cluster_status

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assemblies.name
    taxa_name = taxa[0]
    '''
    #### SETTING UP FOR POPPUNK ####
    echo !{samples} > TEMP
    # create qfile for PopPUNK
    echo !{samples} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    paste s_col a_col > qfile.txt

    # create cache file for the new database
    echo !{new_db} > CACHE

    #### RUN POPPUNK ####
    poppunk_assign \
       --db !{db}  \
       --query qfile.txt \
       --output !{new_db} \
       --update-db \
       --run-qc \
       --max-zero-dist 1 \
       --max-merge 0

    #### COLLECTING CLUSTER INFO ####
    # get cluster info for each sample
    samp=$(cat qfile.txt | cut -f 1)
    echo "sample,cluster,taxa_cluster" > pp_results.csv
    for s in ${samp}
    do
        cat !{new_db}/!{new_db}_clusters.csv | tr ',' '\t' | awk -v s=${s} -v t=!{taxa_name} '$1 == s {print $1,$2,t"_"$2}' | tr ' ' ',' >> pp_results.csv
    done

    # define status for each cluster
    echo "taxa_cluster,status" > cluster_status.csv
    clusts=$(cat pp_results.csv | tr ',' '\t' | cut -f 2 | grep -v "cluster" | sort | uniq)
    for c in ${clusts}
    do
        status=$(cat !{db}/!{db}_clusters.csv | tr ',' '\t' | awk -v c=${c} '$2 == c {print "new"}' | head -n 1)
        if [[ "${status}" == "new" ]]
        then
            echo "!{taxa_name}_${c},old" >> cluster_status.csv
        else
            echo "!{taxa_name}_${c},new" >> cluster_status.csv
        fi
    done
    

    #### VERSION INFO ####
    echo "hello" > versions.yml
    '''
}
