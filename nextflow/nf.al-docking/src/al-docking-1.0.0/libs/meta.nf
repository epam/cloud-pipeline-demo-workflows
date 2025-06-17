// Syntax helper

def ReceptorMeta metaReceptor(Map it) {
    return new ReceptorMeta(it)
}

def ReceptorChunkMeta metaReceptorChunk(Map it) {
    if (!it.chunk)
        throw new Exception("ReceptorChunkMeta requires 'chunk' property")
    return new ReceptorChunkMeta(it)
}

def LigandsMeta metaLigands(Map it) {
    return new LigandsMeta(it)
}

def LigandsChunkMeta metaLigandsChunk(Map it) {
    if (!it.chunk)
        throw new Exception("LigandsChunkMeta requires 'chunk' property")
    return new LigandsChunkMeta(it)
}
