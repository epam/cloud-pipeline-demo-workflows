include { RUN_PLOT_FIGURES    } from '../../modules/local/report/plot_figures'
include { RUN_GENERATE_REPORT } from '../../modules/local/report/generate_report'

workflow GENERATE_REPORT {
    take:
    receptor

    main:
    // receptor.dump(tag: 'GENERATE_REPORT receptor', pretty: true)

    RUN_PLOT_FIGURES(
        receptor.map { [id: it.id] },
        receptor.map { it.iterations_path },
        receptor.map { params.max_iteration_num },
    )
    def report_in = RUN_PLOT_FIGURES.out
        .map { meta, figures ->
            return [[id: meta.id], [figures: figures]]
        }
        .join(
            receptor.map { [[id: it.id], it] },
            by: 0
        )
        .map { it[2] + it[1] }
    // report_in.dump(tag: 'GENERATE_REPORT report_in', pretty: true)

    RUN_GENERATE_REPORT(
        report_in.map { [id: it.id] },
        report_in.map { it.iterations_path },
        report_in.map { it.params_json },
        report_in.map { it.report_template },
    )
    def res_report = RUN_GENERATE_REPORT.out
        .map { meta, report_file -> [meta.id, [report: report_file]] }
        .join(report_in.map { [it.id, it] })
        .map { it[1] + it[2] }
    // def res_report = report_in
    // res_report.dump(tag: 'GENERATE_REPORT res_report', pretty: true)

    emit:
    report = res_report // channel: /path/to/report.html
}
