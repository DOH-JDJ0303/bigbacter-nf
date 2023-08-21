process COMBINED_SUMMARY {

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
    echo ${header} | ' ' '\t' > COMBINED
    cat *.tsv | grep -v "${header}" >> COMBINED
    rm *.tsv
    mv COMBINED !{timestamp}-summary.tsv
    '''
}
