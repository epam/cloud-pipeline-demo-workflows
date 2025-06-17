class LigandsMeta extends MetaBase {

    String role

    LigandsMeta() {
        super()
    }

    LigandsMeta(Map it) {
        super(it)
        this.role = it.role
    }

    @Override
    Tuple key() {
        return Tuple.tuple(this.iteration_num, this.id, this.receptor_hash, this.role, 'LIGANDS')
    }

    @Override
    String toString() {
        return "LigandsMeta { iteration_num: $iteration_num, id: '$id', receptor_hash: '$receptor_hash', role: '$role' }"
    }

}
