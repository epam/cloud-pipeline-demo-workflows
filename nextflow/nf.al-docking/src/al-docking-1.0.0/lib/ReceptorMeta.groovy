class ReceptorMeta extends MetaBase {

    ReceptorMeta() {
        super()
    }

    ReceptorMeta(Map it) {
        super(it)
    }

    @Override
    Tuple key() {
        return Tuple.tuple(this.iteration_num, this.id, this.receptor_hash, 'RECEPTOR')
    }

    @Override
    String toString() {
        return "ReceptorMeta { iteration_num: $iteration_num, id: '$id', receptor_hash: '$receptor_hash' }"
    }

}
