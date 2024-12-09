
//
// Prepare inputs
//

// Modules
include { NCBI_DATASETS     } from '../../modules/local/ncbi-datasets'
include { FASTERQDUMP       } from '../../modules/local/fasterqdump'
include { FASTP             } from '../../modules/local/fastp'
include { SEQTK_SEQ         } from '../../modules/local/seqtk_seq'
include { FORMAT_ASSEMBLY   } from '../../modules/local/format-input'


/*
=============================================================================================================================
    SUBWORKFLOW FUNCTIONS
=============================================================================================================================
*/
//// Function for checking files
def check_file(f, patterns) {
    // Check that the file exists
    if( ! f.exists() ){ exit 1, "ERROR: ${f} does not exist!" }
    // Check that the file is compressed
    if( f.getExtension() == ".gz" ){ exit 1, "ERROR: ${f} is not gz compressed!" }
    // Check the file extension
    f_ext = f.getBaseName().tokenize('.')[-1]
    if( patterns.any{ ext -> ext == f_ext } ){ exit 1, "ERROR: ${f} does not match one of the expected file extensions (${patterns})" }
}

// Function to prepare the samplesheet
def create_sample_channel(LinkedHashMap row) {
    //// Sample Name
    // Check that the sample name was provided
    if( ! row.sample ){exit 1, "ERROR: Sample name not provided!\n${row}"}
    sample = row.sample
    // Check name length
    if(sample.length() > 20){ println "TIP: Short sample names are recommended (${sample})"}

    //// Taxonomy
    // Check that taxonomy was provided, replace all spaces with underscores
    if( ! row.taxa ){ exit 1, "ERROR: Sample taxonomy was not provided!\n${row}"}
    taxa = row.taxa.replaceAll(/ /, "_")
    
    //// Assembly
    assembly = row.assembly ? file(row.assembly) : null
    genbank = row.genbank ? row.genbank : null
    // Check that an assembly type was provided
    if( ! assembly && ! genbank ){ exit 1, "ERROR: An assembly must be provided via the `assembly` or `genbank` columns for ${sample}."}
    // Check that multiple assembly types were not provided
    if( assembly && genbank ){exit 1, "ERROR: Multiple assembly types provided for ${sample}"}
    // Check assembly properties
    if( assembly ){ check_file( assembly, [".fa",".fna",".fasta",".fas"] ) }
    // Check GenBank accession
    if( genbank ){ if( ! "${genbank}" ==~ /^GC[FA]_\d{9}\.\d+$/ ){ exit 1, "ERROR: ${genbank} does not look like a GenBank or RefSeq assembly accession." } }

    //// Reads
    fastq_1 = row.fastq_1 ? file(row.fastq_1) : null
    fastq_2 = row.fastq_2 ? file(row.fastq_2) : null
    fastq_l = row.fastq_l ? file(row.fastq_l) : null
    sra     = row.sra ? row.sra : null
    // Check that at least one read type was provided
    if( ! (fastq_1 && fastq_2) && ! fastq_l && ! sra ){ exit 1, "ERROR: Reads must be provided via the 'fastq_1' and 'fastq_2', 'fastq_l', or 'sra' columns for ${sample}." }
    // Check that only one read type was provided
    if( (fastq_1 && fastq_2) && fastq_l ){ exit 1, "ERROR: Multiple read inputs provided - choose one" }
    if( (fastq_1 && fastq_2) && sra){ exit 1, "ERROR: Multiple read inputs provided - choose one" }
    if( fastq_l && sra ){ exit 1, "ERROR: Multiple read inputs provided - choose one" }
    // Check read formats
    if( fastq_1 ){ check_file( fastq_1, [".fq",".fastq"] ) }
    if( fastq_2 ){ check_file( fastq_2, [".fq",".fastq"] ) }
    if( fastq_l ){check_file( fastq_l, [".fq",".fastq"] ) }
    if( sra ){ if( ! sra ==~ /^SRR\d{8}$/ ){ exit 1, "ERROR: ${sra} does not look like a SRA accession." } }

    //// Optional fields
    cluster = row.cluster ? row.cluster : null

    //// Build output
    result = [ sample: sample, taxa: taxa, assembly: assembly, fastq_1: fastq_1, fastq_2: fastq_2, fastq_l: fastq_l, sra: sra, genbank: genbank, cluster: cluster ]
    
    return result
}

workflow PREPARE_INPUT {
    take:
    ch_input // file: /path/to/samplesheet.csv
    timestamp

    main:
    ch_versions = Channel.empty()

    /*
    =============================================================================================================================
        CHECK SAMPLESHEET
    =============================================================================================================================
    */
    // Check inputs
    Channel
        .fromPath( ch_input )
        .splitCsv ( header:true, sep:',', quote: '"' )
        .map{ it -> create_sample_channel( it ) }
        .set { ch_manifest }

    // Fix duplicate sample names
    ch_manifest
        .map{ it -> [ it.sample, it ] }
        .groupTuple(by: 0)
        .map{ sample, its -> its.eachWithIndex{ it, idx -> it.sample = "${it.sample}_T${idx + 1}"
                                                           it }
                             its }
        .flatten()
        .set{ ch_manifest }
    // /*
    // =============================================================================================================================
    //     PREPARE INPUTS FROM NCBI
    // =============================================================================================================================
    // */
    // MODULE: Download genome assemblies from NCBI
    NCBI_DATASETS(
        ch_manifest.filter{ it -> it.genbank }.map{ it -> [ it.sample, it.genbank ] }
    )
    ch_versions = ch_versions.mix(NCBI_DATASETS.out.versions)
    // Update manifest with GenBank assemblies
    ch_manifest
        .map{ it -> [ it.sample, it ] }
        .join(NCBI_DATASETS.out.assembly, by: 0, remainder: true)
        .map{ sample, it, assembly -> it + [ genbank_assembly: assembly ] }
        .map{ it -> it.assembly = it.genbank_assembly ? it.genbank_assembly : it.assembly
                    it }
        .set{ ch_manifest }

    // // MODULE: Download reads assemblies from NCBI
    FASTERQDUMP(
        ch_manifest.filter{ it -> it.sra }.map{ it -> [ it.sample, it.sra ] }
    )
    ch_versions = ch_versions.mix(FASTERQDUMP.out.versions)
    // Update manifest with SRA reads
    ch_manifest
        .map{ it -> [ it.sample, it ] }
        .join(FASTERQDUMP.out.reads.map{ sample, fastq_1, fastq_2 -> [ sample, [ fastq_1, fastq_2 ] ] }, by: 0, remainder: true)
        .map{ sample, it, reads -> it + [ sra_reads: reads ] }
        .map{ it -> it.fastq_1 = it.sra_reads ? it.sra_reads[0] : it.fastq_1
                    it.fastq_2 = it.sra_reads ? it.sra_reads[1] : it.fastq_2
                    it }
        .set{ ch_manifest }
    /*
    =============================================================================================================================
        QUALITY FILTER INPUTS
    =============================================================================================================================
    */
    if(params.assembly_qc){
        // MODULE: Run seqtk seq on assembly
        SEQTK_SEQ(
            ch_manifest.map{ it -> [ it.sample, it.assembly ] },
            timestamp
        )
        ch_versions = ch_versions.mix(SEQTK_SEQ.out.versions)

        // Add quality filter assemblies back to manifest
        ch_manifest
            .map{ it -> [ it.sample, it ] }
            .join(SEQTK_SEQ.out.assembly, by: 0)
            .map{ sample, it, assembly -> it.assembly = assembly
                                          it }
            .set{ ch_manifest }
    }
    
    // MODULE: Run fastp on reads
    if (params.read_qc){
        FASTP(
            ch_manifest.map{ it -> [ it.sample, it.fastq_1, it.fastq_2 ] },
            timestamp
        )
        ch_versions = ch_versions.mix(FASTP.out.versions)
        
        // Add quality filter reads back to manifest
        ch_manifest
            .map{ it -> [ it.sample, it ] }
            .join(FASTP.out.reads, by: 0)
            .map{ sample, it, fastq_1, fastq_2 -> it.fastq_1 = fastq_1
                                                  it.fastq_2 = fastq_2
                                                  it }
            .set{ ch_manifest }
    }

    /*
    =============================================================================================================================
        FORMAT INPUTS
        - this occurs after all inputs sources have been combined (samplesheet & NCBI)
    =============================================================================================================================
    */
    // MODULE: Gzip assembly (if needed) and rename to format "${sample}.fa.gz"
    FORMAT_ASSEMBLY (
        ch_manifest.map{ it -> [ it.sample, it.assembly ] }
    )
    // Add formatted assembly back to manifest
    ch_manifest
        .map{ it -> [ it.sample, it ] }
        .join(FORMAT_ASSEMBLY.out.assembly, by: 0)
        .map{ sample, it, assembly -> it.assembly = assembly
                                      it }
        .set{ ch_manifest }

    /*
    =============================================================================================================================
        FINALIZE CHANNEL
    =============================================================================================================================
    */
    // Trim down channel fields
    ch_manifest
        .map{ it -> [ sample: it.sample, taxa: it.taxa, assembly: it.assembly, fastq_1: it.fastq_1, fastq_2: it.fastq_2, fastq_l: it.fastq_l, cluster: it.cluster ] }
        .set{ ch_manifest }

    // set validated manifest path - easier ways to do this but this works with Seqera Cloud
    ch_manifest
        .map{ it -> "${it.sample},${it.taxa},${it.assembly},${it.fastq_1},${it.fastq_2},${it.fastq_l},${it.cluster}" }
        .set{samplesheetlines}
    Channel.of("sample,taxa,assembly,fastq_1,fastq_2,fastq_l,cluster")
        .concat(samplesheetlines)
        .collectFile(name: "samplesheet.final.csv", sort: 'index', newLine: true)
        .set{ ch_manifest_path }

    emit:
    manifest      = ch_manifest      // channel: [ val(meta), val(taxa), file(assembly), file(fastq_1), file(fastq_2), file(fastq_l), val(cluster) ]
    manifest_path = ch_manifest_path // channel: [ samplesheet.final.csv ]
    versions      = ch_versions      // channel: [ versions.yml ]
}
