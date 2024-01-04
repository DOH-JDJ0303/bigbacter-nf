
process RESOLVE_MERGED_CLUSTERS {
    tag "${sample}"
    label 'process_low'

    input:
    tuple val(taxa), val(merged_cluster), val(clusters), path(mash_paths, stageAs: "?/*"), val(status), path(assembly), val(sample)

    output:
    path "best_cluster.csv", emit: best_cluster

    when:
    task.ext.when == null || task.ext.when

    shell:
    '''
    # combine mash sketch files by cluster
    echo !{clusters.join(',')} | tr ',' '\n' > clusters
    counter=1
    for c in $(cat clusters)
    do
        mash paste ${c} ${counter}/mash/*.msh
        top_hit=$(mash dist ${c}.msh !{assembly} | sort -g -k 3 | sed -n 1p | cut -f 3)
        echo -e "!{sample}\t!{taxa}\t${c}\t${top_hit}" >> mash_hits.txt
        counter=$((counter+1))
    done

    cat mash_hits.txt | sort -g -k 4 | sed -n 1p | cut -f 1,2,3 | tr '\t' ',' > best_cluster.csv

    # version info
    echo "!{task.process}:\n    mash: $(mash --version | tr -d '\t\n\r ')" > versions.yml
    '''
}