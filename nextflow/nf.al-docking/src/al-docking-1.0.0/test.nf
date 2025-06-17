workflow {
    def c1 = Channel.from(['a', 3], ['b', 2], ['c', 4])
    def c2 = Channel.from(
        [
            ['a', 'a1'],
            ['a', 'a2'],
            ['a', 'a3'],
            ['b', 'b4'],
            ['b', 'b5'],
            ['c', 'с6'],
            ['c', 'с7'],
            ['c', 'с8'],
            ['c', 'с9'],
        ]
    )

    c1
        .combine(c2, by: 0)
        .map { k, size, v ->
            println("#### k: ${k}, size: ${size}, v: ${v}")
            tuple(groupKey(k, size), v)
        }
        .groupTuple(by: 0)
        .view()
}
