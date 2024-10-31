//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv
    timestamp

    main:
    SAMPLESHEET_CHECK( 
        samplesheet,
        timestamp 
    )

    SAMPLESHEET_CHECK
        .out
        .csv
        .splitCsv ( header:true, sep:',' )
        .set { manifest }

    emit:
    manifest                                  // channel: [ val(meta), val(taxa), file(assembly), file(fastq_1), file(fastq_2) ]
    csv = SAMPLESHEET_CHECK.out.csv           // channel: [ samplesheet.valid.csv ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ taxa, assembly, fastq_1, fastq_2] ]
def create_sample_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample
    meta.single_end = row.single_end.toBoolean()

    // check that data is paired end
    if (!meta.single_end) {
        exit 1, "ERROR: Please check input samplesheet -> This pipeline requires paired end reads. Please provide both a forward and reverse read!"
    }

    // check that files exist
    if (!file(row.assembly).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Assembly file does not exist!\n${row.assembly}"
    }
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (!file(row.fastq_2).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
    }
    
    // add path(s) of the fastq file(s) to the meta map
    def sample_meta = []
    sample_meta = [ meta, [ row.taxa, file(row.assembly), file(row.fastq_1), file(row.fastq_2), it.cluster ? it.cluster : null ] ]
    
    return sample_meta
}
