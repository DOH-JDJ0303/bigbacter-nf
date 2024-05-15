process TREE_FIGURE {
    tag "${taxa}_${cluster}_${tree_source}"
    label 'process_low'

    input:
    tuple val(taxa), val(cluster), path(tree), val(tree_source), val(tree_type), val(tree_method),  path(core_stats), path(manifest)
    val timestamp

    output:
    tuple val(taxa), val(cluster), val(tree_source), path("*.jpg*"),      emit: figure, optional: true
    tuple val(taxa), val(cluster), val(tree_source), path("*.final.nwk"), emit: tree

    when:
    task.ext.when == null || task.ext.when

    shell:
    prefix = "${timestamp}-${taxa}-${cluster}"
    '''
    # run script
    tree-figures.R \
        !{tree} \
        "!{manifest}" \
        "!{tree_type}" \
        "!{tree_method}" \
        "!{tree_source}" \
        "!{prefix}" \
        "!{core_stats}" \
        "!{params.max_static}"
    '''
}
