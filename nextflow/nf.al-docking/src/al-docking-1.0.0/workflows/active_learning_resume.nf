include { RUN_RESUME_ITERATION } from '../modules/local/resume/resume_iteration'
include { metaReceptor         } from '../libs/meta'
include { iterToStr            } from '../libs/utils'

workflow RESUME_LOOP {
    take:
    iter

    main:
    // iter.dump(tag: 'RESUME_LOOP iter', pretty: true)

    def args = iter
        .map { it ->
            it.receptors.collect { receptor ->
                // Trying to resume the next iteration
                return receptor + [iteration_num: it.iteration_num + 1]
            }
        }
        .flatMap()
    // args.dump(tag: 'RESUME_LOOP args', pretty: true)

    RUN_RESUME_ITERATION(
        args.map { metaReceptor(it) },
        args.map { it.iterations_path },
    )
    def res_receptor = RUN_RESUME_ITERATION.out
        .map { [it[0].key(), it[1]] }
        .join(args.map { [metaReceptor(it).key(), it] }, by: 0)
        .map { it[2] + it[1] }
    // res_receptor.dump(tag: 'RESUME_LOOP res_receptor', pretty: true)

    def res_iter = res_receptor
        .map { [it.iteration_num - 1, it] }
        .combine(iter.map { [it.iteration_num, it.receptors.size(), it] }, by: 0)
        .map {
            def key = it[0]
            def rec = it[1]
            def size = it[2]
            return [groupKey(key, size), rec.findAll { k, _v -> !(k in ['iteration_num']) }]
        }
        .groupTuple(by: 0)
        .map { [it[0], it[1]] }
        .join(iter.map { [it.iteration_num, it] })
        .map {
            def iteration_num = it[0]
            def receptor_list = it[1]
            def prev = it[2]
            return [
                iteration_num: iteration_num + 1,
                exists: receptor_list.every { r -> r.exists },
                receptors: receptor_list.collect { r -> r.findAll { k, _v -> !(k in ['exists']) } },
                prev: prev.findAll { k, _v -> !(k in ['prev']) },
            ]
        }
    // res_iter.dump(tag: 'RESUME_LOOP res_iter', pretty: true)

    emit:
    iter = res_iter
}
workflow ACTIVE_LEARNING_RESUME {
    take:
    receptor

    main:
    def receptor_ch = receptor

    // receptor_ch.dump(tag: 'ACTIVE_LEARNING_RESUME receptor_ch', pretty: true)
    def iter_val = receptor_ch
        .toList()
        .map { it ->
            return [
                iteration_num: -1,
                receptors: it,
            ]
        }
    // iter_val.dump(tag: 'ACTIVE_LEARNING_RESUME iter_val', pretty: true)

    res_iters = RESUME_LOOP
        .recurse(iter_val)
        .until { iter -> !iter.exists || iter.iteration_num >= params.max_iteration_num - 1 }
        .filter { iter -> !iter.exists || iter.iteration_num >= params.max_iteration_num - 1 }
        .first()
        .map { it.exists ? it : it.prev }
    // res_iters.dump(tag: 'ACTIVE_LEARNING_RESUME res_iters', pretty: true)

    // def res_receptor_resumed = Channel.empty()
    def res_receptor_resumed = res_iters
        .map { it.receptors.collect { r -> r + [iteration_num: it.iteration_num + 1] } }
        .flatten()
    // res_receptor_resumed.dump(tag: 'ACTIVE_LEARNING_RESUME res_receptor_resumed', pretty: true)

    emit:
    receptor = res_receptor_resumed
}
