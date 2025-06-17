include { ACTIVE_LEARNING_START } from './active_learning_start'
include { ACTIVE_LEARNING_RESUME } from './active_learning_resume'
include { ACTIVE_LEARNING_ITERATION } from './active_learning_iteration'

include { metaReceptor } from '../libs/meta'

workflow LOOP {
    take:
    iter

    main:
    // iter.dump(tag: 'LOOP iter', pretty: true)

    def args_all = iter
        .map { it ->
            it.receptors.collect { receptor ->
                return receptor + [iteration_num: it.iteration_num]
            }
        }
        .flatMap()
    def receptor_completed = args_all.filter { it.iteration_num > params.max_iteration_num - 1 }
    def receptor_args = args_all.filter { it.iteration_num <= params.max_iteration_num - 1 }
    // args.dump(tag: 'LOOP receptor_args', pretty: true)

    ACTIVE_LEARNING_ITERATION(receptor_args)
    def receptor_iterated = ACTIVE_LEARNING_ITERATION.out.receptor
    def res_receptor = receptor_iterated.mix(receptor_completed)
    // res_receptor.dump(tag: 'LOOP res_receptor', pretty: true)

    def res_iter = res_receptor
        .map { [it.iteration_num, it] }
        .combine(iter.map { [it.iteration_num, it.receptors.size()] }, by: 0)
        .map {
            def key = it[0]
            def rec = it[1]
            def size = it[2]
            return [groupKey(key, size), rec.findAll { k, _v -> !(k in ['iteration_num']) }]
        }
        .groupTuple(by: 0)
        .map {
            def iteration_num = it[0]
            def rec_list = it[1]
            return [
                iteration_num: iteration_num + 1,
                receptors: rec_list,
            ]
        }
    // res_iter.dump(tag: 'LOOP res_iter', pretty: true)

    emit:
    iter = res_iter
}

workflow ACTIVE_LEARNING {
    take:
    receptor

    main:
    // receptor.dump(tag: 'ACTIVE_LEARNING receptor', pretty: true)
    ACTIVE_LEARNING_RESUME(receptor)

    def receptor_resumed = ACTIVE_LEARNING_RESUME.out.receptor
        .map { [it.id, it] }
        .join(receptor.map { [it.id, it] }, by: 0)
        .map { it[2] + it[1] }
    // receptor_resumed.dump(tag: 'ACTIVE_LEARNING receptor_resumed', pretty: true)

    def receptor_start_in = receptor_resumed
    ACTIVE_LEARNING_START(receptor_start_in, file(params.compound_db))
    def receptor_ch = ACTIVE_LEARNING_START.out.receptor
    // receptor_ch.dump(tag: 'ACTIVE_LEARNING receptor_ch', pretty: true)

    def iter_val = receptor_ch
        .toList()
        .map { list ->
            def iteration_num_list = list*.iteration_num
            def iteration_num = iteration_num_list[0]
            if (!iteration_num_list.every { it == iteration_num }) {
                throw new Exception("ACTIVE_LEARNING iteration_num mismatch: ${list*.iteration_num}")
            }

            return [
                iteration_num: iteration_num,
                receptors: list,
            ]
        }
    // iter_val.dump(tag: 'ACTIVE_LEARNING iter_val', pretty: true)

    def res_iters = LOOP
        .recurse(iter_val)
        .until { iter -> iter.iteration_num >= params.max_iteration_num }
        .collate(params.max_iteration_num)
        .map { it[-1] }
        .first()

    emit:
    iters = res_iters
}
