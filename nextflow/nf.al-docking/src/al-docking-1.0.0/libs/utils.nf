def String iterToStr(iter_num) {
    return iter_num.toString().padLeft(4, '0')
}

String iterTag(meta) {
    // println("#### iterTag(), meta: ${meta}")
    def iter_str = ''
    if (meta.iteration_num instanceof Integer) {
        iter_str = iterToStr(meta.iteration_num)
    }
    else if (meta.iteration_num instanceof String) {
        iter_str = meta.iteration_num
    }
    else {
        throw new RuntimeException("Unsupported type of iteration_num: ${meta.iteration_num.getClass().name}")
    }

    def res = "${meta.id}-${iter_str}"
    return res
}

String iterPublishDir(iterations_path, receptor_meta) {
    def iter_tag = iterTag(receptor_meta)
    def res = "${iterations_path}/${iter_tag}"
    return res
}

String iterationFilesPath(String prefix, meta) {
    def iter_tag = iterToStr(meta.iteration_num)
    def chunk_str = meta.hasProperty('chunk') ? "#${meta.chunk}" : ''
    def res = "${prefix}${meta.role}-${iter_tag}${chunk_str}"
    return res
}

String suffixFilename(filename, String suffix) {
    def String s
    if (filename instanceof Path) {
        s = filename.getName()
    }
    else {
        s = filename.toString()
    }
    def idx = s.lastIndexOf('.')
    def res
    if (idx == -1) {
        res = s + suffix
    }
    else {
        res = s[0..<idx] + suffix + s[idx..-1]
    }
    return res
}

String configHash(path) {
    def String s = getAbsolutePath(path)
    def proc = ['sha256sum', s].execute()
    proc.waitFor()

    if (proc.exitValue() != 0) {
        def err = proc.err.text
        println("ERROR: ${err}")
        throw new RuntimeException("sha256sum failed: ${err}")
    }

    def String hash = proc.text.tokenize()[0]
    def String res = hash[0..(6 - 1)]
    return res
}

String getPath(path) {
    def String res
    if (path instanceof Path) {
        res = path.toString()
    }
    else {
        res = path.toString()
    }
    return res
}

String getAbsolutePath(path) {
    def s = getPath(path)
    def file = new File(s)
    def res = file.getCanonicalPath()
    // println("#### makeAbsolutePath: '${path}' resolved to '${res}'.")
    return res
}

Boolean isNoFile(path) {
    def s = getPath(path)
    def file = new File(s)
    def res = file.getName().startsWith('NO_FILE')
    // println("#### isNoFile(), file.getName(): ${file.getName()}, res: ${res}")
    return res
}

List ensureList(obj) {
    if (obj instanceof List) {
        return obj
    }
    else {
        return [obj]
    }
}
