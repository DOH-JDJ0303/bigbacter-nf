process GET_PP_DB {

    input:
    tuple path(cache), val(sample), val(taxa), val(assembly), val(source)

    output:
    tuple stdout, val(sample), val(taxa), val(assembly), emit: pp_list
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    cdb=$(cat !{cache})
    echo "!{source}${cdb}/" | tr -d '\t\n\r '
    
    echo "hello" > versions.yml
    '''
}
