#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    epam/al-docking
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/epam/al-docking
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2
nextflow.preview.recursion = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML                   } from './subworkflows/nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap                         } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                     } from './subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                   } from './subworkflows/local/utils_pipeline'

include { PIPELINE_INITIALISATION                  } from './subworkflows/local/utils_pipeline'
include { PIPELINE_COMPLETION                      } from './subworkflows/local/utils_pipeline'

include { PREPARE_RECEPTOR                         } from './subworkflows/local/prepare_receptor'
include { ACTIVE_LEARNING                          } from './workflows/active_learning'
include { INFER_UNLABELED_CHUNKS as INFER_DATABASE } from './subworkflows/local/infer_unlabeled_chunks'
include { RUN_PUBLISH_FILE as RUN_PUBLISH_MODEL    } from './modules/local/utils/publish_file'
include { GENERATE_REPORT                          } from './subworkflows/local/generate_report'

include { metaReceptor                             } from './libs/meta'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NF_AL_DOCKING {
    take:
    input_receptors
    params_json

    main:
    ch_versions = Channel.empty()

    def input_receptors_val = input_receptors
    PREPARE_RECEPTOR(input_receptors)
    def prepared_receptor_ch = PREPARE_RECEPTOR.out.receptor_ch
    // Channel with maps

    // println("######## iterations_path: ${iterations_path}")
    ACTIVE_LEARNING(prepared_receptor_ch)
    def learned_iters = ACTIVE_LEARNING.out.iters
    // learned_iters.dump(tag: 'NF_AL_DOCKING learned_iters', pretty: true)

    def learned_receptor = learned_iters
        .map { it.receptors }
        .flatten()
    // learned_receptor.dump(tag: 'NF_AL_DOCKING learned_receptor', pretty: true)

    def infer_db_in = learned_receptor.map {
        it + [
            unlabeled: file(params.compound_db),
            iteration_num: "out",
            iterations_path: "${params.outdir}",
        ]
    }
    // infer_db_in.dump(tag: 'NF_AL_DOCKING infer_db_in', pretty: true)
    INFER_DATABASE(infer_db_in)
    RUN_PUBLISH_MODEL(
        infer_db_in.map {
            def res = metaReceptor(it)
            // println("#### metaReceptor: ${res}")
            return res
        },
        infer_db_in.map {
            def res = it.model_pth
            // println("#### model_pth: ${res}")
            return res
        },
        infer_db_in.map {
            def res = it.iterations_path
            // println("#### iterations_path: ${res}")
            return res
        },
    )

    def report_template = Channel.fromPath("${projectDir}/assets/report_template.html")
    def report_in = learned_receptor
        .combine(report_template.map { [report_template: it] })
        .combine(params_json.map { [params_json: it] })
        .map { it[0] + it[1] + it[2] }
    // report_in.dump(tag: 'NF_AL_DOCKING report_in', pretty: true)
    GENERATE_REPORT(report_in)

    def output_receptor = learned_receptor
        .map { [it.id, it] }
        .join(
            INFER_DATABASE.out.receptor_inferred.map { [it.id, [database_inferred: it.inferred]] },
            by: 0
        )
        .join(
            RUN_PUBLISH_MODEL.out.map { meta, _file -> [meta.id, []] },
            by: 0
        )
        .join(
            GENERATE_REPORT.out.report.map { [it.id, [report: it.report]] },
            by: 0
        )
        .map { it[1] + it[2] + it[3]}
    // output_receptor.dump(tag: 'NF_AL_DOCKING output_receptor', pretty: true)

    def res_output = output_receptor

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'al.docking_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }

    emit:
    output   = res_output
    versions = ch_versions // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.receptor_sheet,
        params.receptor_path,
        params.iterations_path,
        params.cache_zip,
        params.cache_path,
    )

    def receptor_ch = PIPELINE_INITIALISATION.out.receptor
    def params_json = PIPELINE_INITIALISATION.out.params_json
    // nf_al_docking_in.dump(tag: 'PIPELINE_INITIALISATION out receptor', pretty: true)

    //
    // WORKFLOW: Run main workflow
    //
    def (res_iters, _res_versions) = NF_AL_DOCKING(receptor_ch, params_json)

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.outdir,
        params.monochrome_logs,
        params.cache_path,
        res_iters
    )
}
