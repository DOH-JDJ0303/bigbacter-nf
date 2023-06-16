process ASSIGN_PP_CLUSTER {
    container 'staphb/poppunk:2.6.0'

    input:
    tuple path(db), val(samples), path(assemblies)

    output:
    path 'pp_results.csv'

    when:
    task.ext.when == null || task.ext.when

    shell:
    assembly_names = assemblies.name
    '''
    # create qfile for PopPUNK
    echo !{samples} | tr -d '[] ' | tr ',' '\n' > s_col
    echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' > a_col
    paste s_col a_col > qfile.txt

    # create new database name
    new_db=$(date +%s)

    # run PopPUNK
    poppunk_assign \
       --db !{db}  \
       --query qfile.txt \
       --output ${new_db} \
       --update-db \
       --run-qc \
       --max-zero-dist 1 \
       --max-merge 0


    # get list of references for each cluster
    refs=$(cat ${new_db}/${new_db}.refs)
    for r in ${refs}
    do
        cat ${new_db}/${new_db}_clusters.csv | tr ',' '\t' | awk -v s=${r} '$1 == s {print $0}' >> REF_CLUSTERS
    done
    # get cluster info for each sample
    samp=$(cat qfile.txt | cut -f 1)
    for s in ${samp}
    do
        cat ${new_db}/${new_db}_clusters.csv | tr ',' '\t' | awk -v s=${s} '$1 == s {print $0}' >> SAMP_CLUSTERS
    done
    # get reference info for each sample
    clus=$(cat SAMP_CLUSTERS | cut -f 2)
    for c in ${clus}
    do
        cat REF_CLUSTERS | awk -v s=${c} '$2 == s {print $1}' >> SAMP_REFS
    done
    # combine all together
    echo "sample,cluster,reference"
    paste SAMP_CLUSTERS SAMP_REFS | tr '\t' ',' > pp_results.csv
    
    echo "hello" > versions.yml
    '''
}
