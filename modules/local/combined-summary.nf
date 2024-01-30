process COMBINED_SUMMARY {
    tag "${timestamp}"
    label 'process_low'

    input:
    path summary_files
    path manifest_file
    val timestamp

    output:
    path "*-summary.tsv", emit: summary

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # combine summaries
    header=$(sed -n 1p *.tsv) 
    echo ${header} | tr ' ' '\t' > COMBINED
    cat *.tsv | grep -v "${header}" >> COMBINED
    rm *.tsv
    mv COMBINED !{timestamp}-summary.tsv

    # make sure all samples made it
    cat !{manifest_file} | awk -F ',' '$1 != "sample" {print $1}' | sort > m_col
    cat !{timestamp}-summary.tsv | awk '$1 != "ID" {print $1}' | sort > s_col
    missing=$(comm -23 m_col s_col)
    if [[ ! -z "${missing}" ]]
    then
        echo -e "Error: Summary files were not generated for the following samples. Please submit an issue at https://github.com/DOH-JDJ0303/bigbacter-nf/issues."
        echo -e "$(echo ${missing} | tr ' ' '\n')"
        exit 1
    fi
    '''
}
