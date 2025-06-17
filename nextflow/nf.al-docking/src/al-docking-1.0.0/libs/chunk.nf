def String getChunk(path) {
    // println("#### getChunk(), path: ${path}")
    def pattern = ~/.*\#(chunk_\w+)\.csv$/
    def m = path.toString() =~ pattern
    if (!m.matches()) {
        throw new RuntimeException("Chunk not found in path: ${path}")
    }
    return m[0][1]
}
