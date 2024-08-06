# StableTasks.jl

StableTasks is a simple package that provides *type stable* tools for creating (regular and *sticky*) tasks. It has the following API (no exports):

* `StableTasks.@spawn`
* `StableTasks.@spawnat`
* `StableTasks.@fetch`
* `StableTasks.@fetchfrom`

## `StableTasks.@spawn`

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

## `StableTasks.@spawnat`

The package also provides `StableTasks.@spawnat`, which is similar to `StableTasks.@spawn` but creates a *sticky* task (that won't migrate) on a specific thread.

```julia
julia> t = StableTasks.@spawnat 4 Threads.threadid();

julia> @inferred fetch(t)
4
```

## `StableTasks.@fetch` and `StableTasks.@fetchfrom`

For convenience, and similar to at Distributed.jl, we also provide `@fetch` and `@fetchfrom` macros:

```julia
julia> StableTasks.@fetch 3+3
6

julia> StableTasks.@fetchfrom 2 Threads.threadid()
2
```
