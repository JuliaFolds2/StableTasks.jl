module StableTasks

macro spawn end
macro spawnat end

mutable struct AtomicRef{T}
    @atomic x::T
    AtomicRef{T}() where {T} = new{T}()
    AtomicRef(x::T) where {T} = new{T}(x)
    AtomicRef{T}(x) where {T} = new{T}(convert(T, x))
end

mutable struct StableTask{T}
    const t::Task
    ret::AtomicRef{T}
end

include("internals.jl")

end # module StableTasks
