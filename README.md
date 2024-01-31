# StableTasks.jl

StableTasks is a simple package with one main API `StableTasks.@spawn` (not exported by default). 

It works like `Threads.@spawn`, except it is *type stable* to `fetch` from.

``` julia
julia> using StableTasks, Test

julia> @inferred fetch(StableTasks.@spawn 1 + 1)
2
```
versus

``` julia
julia> @inferred fetch(Threads.@spawn 1 + 1)
ERROR: return type Int64 does not match inferred return type Any
Stacktrace:
 [1] error(s::String)
   @ Base ./error.jl:35
 [2] top-level scope
   @ REPL[3]:1
```

The package also provides `StableTasks.@spawnat` (not exported), which is similar to `StableTasks.@spawn` but creates a *sticky* task (it won't migrate) on a specific thread.

```julia
julia> t = StableTasks.@spawnat 4 Threads.threadid();

julia> @inferred fetch(t)
4
```
