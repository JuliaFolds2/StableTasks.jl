module StableTasks

macro spawn end
macro spawnat end

using Base: RefValue
struct StableTask{T}
    t::Task
    ret::RefValue{T}
end

include("internals.jl")

end # module StableTasks
