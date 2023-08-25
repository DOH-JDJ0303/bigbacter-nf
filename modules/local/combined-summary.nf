process COMBINED_SUMMARY {
    tag "${timestamp}"
    label 'process_low'

    input:
    path summary_files
    val timestamp

    output:
    path "*-summary.tsv", emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    header=$(sed -n 1p *.tsv) 
    echo ${header} | tr ' ' '\t' > COMBINED
    cat *.tsv | grep -v "${header}" >> COMBINED
    rm *.tsv
    mv COMBINED !{timestamp}-summary.tsv
    '''
}
