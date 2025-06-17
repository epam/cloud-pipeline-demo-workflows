class ReceptorChunkMeta extends ReceptorMeta {

    String chunk

    ReceptorChunkMeta() {
        super()
    }

    ReceptorChunkMeta(Map it) {
        super(it)
        this.chunk = it.chunk
    }

    @Override
    Tuple key() {
        return Tuple.tuple(this.iteration_num, this.id, this.receptor_hash, this.chunk, 'RECEPTOR_CHUNK')
    }

    @Override
    String toString() {
        return "ReceptorChunkMeta { iteration_num: $iteration_num, id: '$id', receptor_hash: '$receptor_hash', chunk: '$chunk' }"
    }

}
