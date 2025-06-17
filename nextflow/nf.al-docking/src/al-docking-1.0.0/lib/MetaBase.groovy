abstract class MetaBase {

    // Can be either int or String
    def iteration_num
    String id
    String receptor_hash

    protected MetaBase() {}

    protected MetaBase(Map it) {
        this.iteration_num = it.iteration_num
        this.id = it.id
        this.receptor_hash = it.receptor_hash
    }

    abstract Tuple key()

    abstract String toString()
}
