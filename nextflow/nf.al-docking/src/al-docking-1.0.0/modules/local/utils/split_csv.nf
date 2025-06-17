include { iterTag  } from '../../../libs/utils'
include { isNoFile } from '../../../libs/utils'

process RUN_SPLIT_CSV {
    tag "${iterTag(meta)}${meta.hasProperty('role') ? "-${meta.role}" : ""}"
    label 'process_single'

    publishDir '', enabled: false

    input:
    val meta
    path input_csv
    val chunk_size

    output:
    tuple val(meta), path("${input_csv}#*.csv")

    script:
    // println("######## RUN_SPLIT_CSV, input_csv: ${input_csv}")
    // println("######## RUN_SPLIT_CSV, chunk_size: ${chunk_size}")
    def script = ''
    if (isNoFile(input_csv)) {
        script = """
        touch "${input_csv}#chunk_00.csv"
        touch "${input_csv}#chunk_01.csv"
        """
    }
    else {
        script = """
        tail -n +2 ${input_csv} | split -l ${chunk_size} - chunk_
        for f in chunk_*; do
            echo \$(head -n 1 ${input_csv}) | cat - \$f > \$f.tmp && mv \$f.tmp ${input_csv}#\$f.csv
            truncate --size=0 \$f
        done
        """
    }
    return script
}
