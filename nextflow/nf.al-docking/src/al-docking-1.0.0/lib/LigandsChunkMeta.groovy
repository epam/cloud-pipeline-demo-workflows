class LigandsChunkMeta extends LigandsMeta {

    String chunk

    LigandsChunkMeta() {
        super()
    }

    LigandsChunkMeta(Map it) {
        super(it)
        this.chunk = it.chunk
    }

    @Override
    Tuple key() {
        return Tuple.tuple(this.iteration_num, this.id, this.receptor_hash, this.role, this.chunk, 'LIGANDS_CHUNK')
    }

    @Override
    String toString() {
        return "LigandsChunkMeta { iteration_num: $iteration_num, id: '$id', receptor_hash: '$receptor_hash', role: '$role', chunk: '$chunk' }"
    }

}
