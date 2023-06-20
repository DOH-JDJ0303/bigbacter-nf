process ASSIGN_PP_CLUSTER {
    container 'staphb/poppunk:2.6.0'

    input:
    tuple path(db), val(samples), val(taxa), path(assemblies)
    val new_db

    output:
    path 'pp_results.csv', emit: cluster_results
    tuple path(new_db), path('CACHE'), val(taxa_name), path('new_refs/*.fa'), emit: new_pp_db

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assemblies.name
    taxa_name = taxa[0]
    '''
    #### SETTING UP FOR POPPUNK ####
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

    #### DETECT NEW CLUSTERS ####
    # make directory and add empty file
    mkdir new_refs
    touch new_refs/placeholder.tmp.fa
    # copy over BigBacter reference list to new database
    cp !{db}/*_bb_refs.tsv !{new_db}/!{new_db}_bb_refs.tsv
    # searching for new clusters
    cat !{db}/!{db}_clusters.csv | tr ',' '\t' | cut -f 2 | sort | uniq > old.txt
    cat !{new_db}/!{new_db}_clusters.csv | tr ',' '\t' | cut -f 2 | sort | uniq > new.txt
    new_clusters=$(comm -13 old.txt new.txt)
    # check if new clusters were detected
    if [[ -n "${new_clusters}" ]]
    then
        for c in ${new_clusters}
        do
            # update the BigBacter reference list
            cat !{new_db}/!{new_db}_clusters.csv | tr ',' '\t' | awk -v c=${c} '$2 == c {print $0}' | head -n 1 >> !{new_db}/!{new_db}_bb_refs.tsv
            s=$(cat !{new_db}/!{new_db}_bb_refs.tsv | cut -f 1 | tail -n 1)
            # rename the input assembly and queue for pushing to databse
            a=$(cat qfile.txt | awk -v s=${s} '$1 == s {print $2}')
            cp ${a} new_refs/${s}.fa
            
        done
    fi

    #### COLLECTING CLUSTER & REFERENCE INFO ####
    # get cluster info for each sample
    samp=$(cat qfile.txt | cut -f 1)
    for s in ${samp}
    do
        cat !{new_db}/!{new_db}_clusters.csv | tr ',' '\t' | awk -v s=${s} '$1 == s {print $0}' >> SAMP_CLUSTERS
    done
    # get reference info for each sample
    row=$(cat SAMP_CLUSTERS | tr '\t' ',')
    for r in ${row}
    do
        s=$(echo ${r} | tr ',' '\t' | cut -f 1)
        c=$(echo ${r} | tr ',' '\t' | cut -f 2)
        cat !{new_db}/!{new_db}_bb_refs.tsv | awk -v s=${c} '$2 == s {print $1}' >> SAMP_REFS
    done
    # combine all together
    echo "sample,cluster,reference" > pp_results.csv
    paste SAMP_CLUSTERS SAMP_REFS | tr '\t' ',' >> pp_results.csv

    #### VERSION INFO ####
    echo "hello" > versions.yml
    '''
}
