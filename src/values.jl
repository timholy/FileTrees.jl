export load, mapvalues, reducevalues, save, NoValue, hasvalue

lazify(flag::Nothing, f) = _lazy_if_lazy(f)
lazify(flag::Bool, f) = flag ? lazy(f) : f

"""
apply `f` to any node that has a value. `f` gets the node itself
and must return a node.
"""
function mapvalued(f, t::Node; walk=postwalk)
    walk(x->hasvalue(x) ? f(x) : x, t)
end

"""
    load(f, t::FileTree; dirs=false)

Walk the tree and optionally load data for nodes in it.

`f(file)` is the loader function which takes `File` as input.
Call `path(file)` to get the String path to read the  file.

If `dirs = true` then `f` can either get a `File` or `FileTree`.
nodes within `FileTree` will have already been loaded.

If `NoValue()` is returned by `f`, no value is attached to the node.
`hasvalue(x)` tells you if `x` already has a value or not.
"""
function load(f, t::Node; dirs=false, walk=postwalk, lazy=false)

    loader = x -> begin
        (!dirs && x isa FileTree) && x
        f′ = lazify(lazy, f)
        typeof(x)(x, value=f′(x))
    end

    walk(loader, t)
end

"""
    mapvalues(f, x::FileTree)

(See `load` to load values into nodes of a tree.)

Apply `f` to the value of all nodes in `x` which have a value.
Returns a new tree where every value is replaced with the result of applying `f`.

`f` may return `NoValue()` to cause no value to be associated with a node.
"""
function mapvalues(f, t::Node; lazy=nothing)
    mapvalued(x -> typeof(x)(x; value=lazify(lazy, f)(value(x))), t)
end

"""
    reducevalues(f, t::FileTree; associative=true)

Use `f` to combine values in the tree.

- `associative=true` assumes `f` can be applied in an associative way
"""
function reducevalues(f, t::FileTree; associative=true, lazy=nothing)
    f′ = lazify(lazy, f)
    itr = value.(collect(Iterators.filter(hasvalue, Leaves(t))))
    associative ? assocreduce(f′, itr) : reduce(f′, itr)
end

"""
Associative reduce
"""
function assocreduce(f, xs)
    length(xs) == 1 && return xs[1]
    l = length(xs)
    m = div(l, 2)
    f(assocreduce(f, xs[1:m]), assocreduce(f, xs[m+1:end]))
end

"""
    save(f, x::Node)

Save a FileTree to disk. Creates the directory structure
and calls `f` with `File` for every file in the tree which
has a value associated with it.

(see `load` and `mapvalues` for associating values with files.)
"""
function save(f, t::Node; lazy=nothing)
    mapvalued(t->isempty(t) ? NoValue() : typeof(t)(t; value=lazify(lazy, x->(mkpath(dirname(t)); f(x)))(t)), t)
end