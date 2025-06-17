//
// Post processing analysis for the predicted structures
//

//
// SUBWORKFLOW: Consisting entirely of nf-core/modules
//
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from './utils_nfcore_proteinfold_pipeline'

include { GENERATE_REPORT     } from '../../modules/local/generate_report'
include { COMPARE_STRUCTURES  } from '../../modules/local/compare_structures'
include { FOLDSEEK_EASYSEARCH } from '../../modules/nf-core/foldseek/easysearch/main'
include { MULTIQC             } from '../../modules/nf-core/multiqc/main'


workflow POST_PROCESSING {

    take:
    skip_visualisation
    requested_modes
    requested_modes_size
    ch_report_input
    ch_report_template
    ch_comparison_template
    foldseek_search
    ch_foldseek_db
    skip_multiqc
    outdir
    ch_versions
    ch_multiqc_rep
    ch_multiqc_config
    ch_multiqc_custom_config
    ch_multiqc_logo
    ch_multiqc_methods_description
    ch_alphafold2_top_ranked_pdb
    ch_esmfold_top_ranked_pdb
    ch_rosettafold_all_atom_top_ranked_pdb

    main:

    ch_alphafold2_top_ranked_pdb.dump(tag: "POST_PROCESSING ch_alphafold2_top_ranked_pdb", pretty: true)
    ch_esmfold_top_ranked_pdb.dump(tag: "POST_PROCESSING ch_esmfold_top_ranked_pdb", pretty: true)
    ch_rosettafold_all_atom_top_ranked_pdb.dump(tag: "POST_PROCESSING ch_rosettafold_all_atom_top_ranked_pdb", pretty: true)

    ch_comparison_report_files = Channel.empty()
    ch_sequence_coverage_files = Channel.empty()

    if (!skip_visualisation){
        // ch_report_input.dump(tag: "POST_PROCESSING ch_report_input", pretty: true)

        GENERATE_REPORT(
            ch_report_input.map { [it[0], it[1]] },   // meta, pdb
            ch_report_input.map { [it[0], it[2]] },   // meta_msa, msa
            ch_report_input.map { it[0].model },      // output_type
            ch_report_template                        // template
        )
        ch_versions = ch_versions.mix(GENERATE_REPORT.out.versions)
      
        if (requested_modes_size > 1){
            ch_sequence_coverage_files = ch_sequence_coverage_files.mix(GENERATE_REPORT.out.sequence_coverage)
            ch_sequence_coverage_files.dump(tag: "POST_PROCESSING ch_sequence_coverage_files", pretty: true)

            ch_comparison_report_files = ch_comparison_report_files
                .mix(ch_alphafold2_top_ranked_pdb)
                .mix(ch_esmfold_top_ranked_pdb)
                .mix(ch_rosettafold_all_atom_top_ranked_pdb)
                .map{ it[1, 2] }
                .join(ch_sequence_coverage_files, by: 0)
            ch_comparison_report_files.dump(tag: "POST_PROCESSING ch_comparison_report_files", pretty: true)

            ch_comparison_report_input = ch_comparison_report_files
                .map { tuple(it[0].id, *it) }
                .groupTuple(by: [0], size: requested_modes_size)
            ch_comparison_report_input.dump(tag: "POST_PROCESSING ch_comparison_report_input", pretty: true)

            ch_pdb = ch_comparison_report_input.map {
                [[id: it[0], models: it[1]*.model.join(',')], it[2] ]
            }
            ch_msa = ch_comparison_report_input.map {
                [[id: it[0], models: it[1]*.model.join(',')], it[3] ]
            }
            ch_pdb.dump(tag: "POST_PROCESSING ch_pdb", pretty: true)
            ch_msa.dump(tag: "POST_PROCESSING ch_msa", pretty: true)

            COMPARE_STRUCTURES(ch_pdb, ch_msa, ch_comparison_template)
            ch_versions = ch_versions.mix(COMPARE_STRUCTURES.out.versions)
        }
    }

    if (foldseek_search == "easysearch"){
        FOLDSEEK_EASYSEARCH(
            ch_report_input
                .map{
                    if (it[0].model == "esmfold")
                        [ it[0], it[1] ]
                    else
                        [ it[0], it[1][0] ]
                    },
            ch_foldseek_db
        )
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'proteinfold_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_report = Channel.empty()

    if (!skip_multiqc) {
        summary_params           = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary      = Channel.value(paramsSummaryMultiqc(summary_params))
        ch_methods_description   = Channel.value(methodsDescriptionText(ch_multiqc_methods_description))

        ch_multiqc_files = Channel.empty()
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)

        MULTIQC (
            ch_multiqc_rep
                .combine(
                    ch_multiqc_files
                        .collect()
                        .map { [it] }
                )
            .map { [ it[0], it[1] + it[2] ] },
            ch_multiqc_config,
            ch_multiqc_custom_config
                .collect()
                .ifEmpty([]),
            ch_multiqc_logo
                .collect()
                .ifEmpty([]),
            [],
            []
        )
        ch_multiqc_report = MULTIQC.out.report.toList()
    }

    emit:
    versions       = ch_versions
    multiqc_report = ch_multiqc_report
}
