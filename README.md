# StableTasks.jl

StableTasks is a simple package with one main API `StableTasks.@spawn` (not exported by default). 

It works like `Threads.@spawn`, except it is *type stable* to `fetch` from (and it does not yet support threadpools
other than the default threadpool).

``` julia
julia> Core.Compiler.return_type(() -> fetch(StableTasks.@spawn 1 + 1), Tuple{})
Int64
```
versus

``` julia
julia> Core.Compiler.return_type(() -> fetch(Threads.@spawn 1 + 1), Tuple{})
Any
```
