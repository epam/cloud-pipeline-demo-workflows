include { iterToStr      } from '../../../libs/utils'
include { iterPublishDir } from '../../../libs/utils'
include { iterTag        } from '../../../libs/utils'
include { suffixFilename } from '../../../libs/utils'
include { isNoFile       } from '../../../libs/utils'

def Map getIterFiles(meta) {
    return [
        model_pth: "${iterTag(meta)}.model.pth",
        valid_docked_csv: "validation-${meta.id}.pdb.pdbqt.docked.csv",
        unlabeled: "${iterTag(meta)}.unlabeled.csv",
        inferred: "${iterTag(meta)}.unlabeled.inferred.csv",
        train_before_inferred_csv: "${iterTag(meta)}.train.pdb.pdbqt.docked.before-inferred.csv",
        test_before_inferred_csv: "${iterTag(meta)}.test.pdb.pdbqt.docked.before-inferred.csv",
        train_inferred_csv: "${iterTag(meta)}.train.pdb.pdbqt.docked.inferred.csv",
    ]
}

process RUN_RESUME_ITERATION {
    tag "${iterTag(meta)}"
    label "process_single"
    // container "al-docking:1.0.0"

    input:
    val meta
    val iterations_path

    output:
    tuple val(meta), val {
        def iter_path = iterPublishDir(iterations_path, meta)
        def iter_files = getIterFiles(meta)
        def exists = iter_files
            .values()
            .every { fn -> new File(iter_path, fn).exists() }
        def res = [exists: exists] + iter_files.collectEntries { k, fn -> [k, file(new File(iter_path, fn))] }
        // println("#### RUN_RESUME_ITERATION res: ${res}")
        return res
    }

    script:
    def iter_path = iterPublishDir(iterations_path, meta)
    def iter_files = getIterFiles(meta)
    // println("######## iter_path: ${iter_path}")
    // println("######## iter_files: ${iter_files}")
    def exists = iter_files.every { k, fn -> new File(iter_path, fn).exists() }

    def script = ""
    if (exists) {
        script = iter_files.values().collect { fn -> """ln -s "${iter_path}/${fn}" "${fn}" """ }.join("\n")
    }
    else {
        script = iter_files.values().collect { fn -> """touch "${fn}" """ }.join("\n")
    }

    return script
}
