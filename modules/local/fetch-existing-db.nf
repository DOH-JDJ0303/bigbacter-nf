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
    assembly_names = assemblies.name
    taxa_name      = taxa[0]
    cluster_name   = cluster[0]
    '''    
    # check if there is a reference assigned - if not, assign a reference
    if [[ ! -f "!{bb_db}/ref/!{taxa_name}-!{cluster_name}-ref.fa" ]]
    then
        echo "!{bb_db}/ref/ contains: $(ls !{bb_db}/ref/)"
        echo "Creating new reference"
        # select first assembly as reference - this has a lot of room for improvement
        ref=$(echo !{assembly_names} | tr -d '[] ' | tr ',' '\n' | head -n 1)
        # rename the assembly
        mv ${ref} !{bb_db}/ref/!{taxa_name}-!{cluster_name}-ref.fa
    fi

    # if there are no old Snippy files, add a dummy file called "main.nf"
    if [[ ! -f "!{bb_db}/snippy/*" ]]
    then
        touch !{bb_db}/snippy/main.nf
    fi
    '''
}
