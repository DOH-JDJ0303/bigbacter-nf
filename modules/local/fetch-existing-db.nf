process FETCH_EXISTING_DB {
    input:
    tuple val(taxa_cluster), val(sample), val(taxa), path(assemblies), val(fastq_1), val(fastq_2), val(cluster), val(status), path(bb_db)
    val timestamp

    output:
    tuple val(taxa_cluster), path("${bb_db}/ref/*.fa", includeInputs: true),       emit: reference
    tuple val(taxa_cluster), path("${bb_db}/snippy/*", includeInputs: true), emit: old_var_files
   
    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # if there are no old Snippy files, add a dummy file called "main.nf"
    if [[ ! -f "!{bb_db}/snippy/*" ]]
    then
        touch !{bb_db}/snippy/main.nf
    fi
    '''
}
