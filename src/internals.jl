module Internals

import StableTasks: @spawn, @spawnat, StableTask, AtomicRef

Base.getindex(r::AtomicRef) = @atomic r.x
Base.setindex!(r::AtomicRef{T}, x) where {T} = @atomic r.x = convert(T, x)

function Base.fetch(t::StableTask{T}) where {T}
    fetch(t.t)
    t.ret[]
end

for func ∈ [:wait, :istaskdone, :istaskfailed, :istaskstarted, :yield, :yieldto]
    if isdefined(Base, func)
        @eval Base.$func(t::StableTask) = $func(t.t)
    end
end

Base.yield(t::StableTask, x) = yield(t.t, x)
Base.yieldto(t::StableTask, x) = yieldto(t.t, x)
if isdefined(Base, :current_exceptions)
    Base.current_exceptions(t::StableTask; backtrace::Bool=true) = current_exceptions(t.t; backtrace)
end
if isdefined(Base, :errormonitor)
    Base.errormonitor(t::StableTask) = errormonitor(t.t)
end
Base.schedule(t::StableTask) = (schedule(t.t); t)
Base.schedule(t, val; error=false) = (schedule(t.t, val; error); t)

"""
    @spawn [:default|:interactive] expr

Similar to `Threads.@spawn` but type-stable. Creates a `Task` and schedules it to run on any available
thread in the specified threadpool (defaults to the `:default` threadpool).
"""
macro spawn(args...)
    tp = QuoteNode(:default)
    na = length(args)
    if na == 2
        ttype, ex = args
        if ttype isa QuoteNode
            ttype = ttype.value
            if ttype !== :interactive && ttype !== :default
                throw(ArgumentError("unsupported threadpool in StableTasks.@spawn: $ttype"))
            end
            tp = QuoteNode(ttype)
        else
            tp = ttype
        end
    elseif na == 1
        ex = args[1]
    else
        throw(ArgumentError("wrong number of arguments in @spawn"))
    end

    letargs = _lift_one_interp!(ex)

    thunk = replace_linenums!(:(() -> ($(esc(ex)))), __source__)
    var = esc(Base.sync_varname) # This is for the @sync macro which sets a local variable whose name is
    # the symbol bound to Base.sync_varname
    # I asked on slack and this is apparently safe to consider a public API
    quote
        let $(letargs...)
            f = $thunk
            T = Core.Compiler.return_type(f, Tuple{})
            ref = AtomicRef{T}()
            f_wrap = () -> (ref[] = f(); nothing)
            task = Task(f_wrap)
            task.sticky = false
            Threads._spawn_set_thrpool(task, $(esc(tp)))
            if $(Expr(:islocal, var))
                put!($var, task) # Sync will set up a Channel, and we want our task to be in there.
            end
            schedule(task)
            StableTask{T}(task, ref)
        end
    end
end

"""
    @spawnat thrdid expr

Similar to `StableTasks.@spawn` but creates a **sticky** `Task` and schedules it to run on the thread with the given id (`thrdid`).
The task is guaranteed to stay on this thread (it won't migrate to another thread).
"""
macro spawnat(thrdid, ex)
    letargs = _lift_one_interp!(ex)

    thunk = replace_linenums!(:(() -> ($(esc(ex)))), __source__)
    var = esc(Base.sync_varname)

    tid = esc(thrdid)
    @static if VERSION < v"1.9"
        nt = :(Threads.nthreads())
    else
        nt = :(Threads.maxthreadid())
    end
    quote
        if $tid < 1 || $tid > $nt
            throw(ArgumentError("Invalid thread id ($($tid)). Must be between in " *
                                "1:(total number of threads), i.e. $(1:$nt)."))
        end
        let $(letargs...)
            thunk = $thunk
            RT = Core.Compiler.return_type(thunk, Tuple{})
            ret = AtomicRef{RT}()
            thunk_wrap = () -> (ret[] = thunk(); nothing)
            local task = Task(thunk_wrap)
            task.sticky = true
            ccall(:jl_set_task_tid, Cvoid, (Any, Cint), task, $tid - 1)
            if $(Expr(:islocal, var))
                put!($var, task)
            end
            schedule(task)
            StableTask(task, ret)
        end
    end
end

# Copied from base rather than calling it directly because who knows if it'll change in the future
function _lift_one_interp!(e)
    letargs = Any[]  # store the new gensymed arguments
    _lift_one_interp_helper(e, false, letargs) # Start out _not_ in a quote context (false)
    letargs
end
_lift_one_interp_helper(v, _, _) = v
function _lift_one_interp_helper(expr::Expr, in_quote_context, letargs)
    if expr.head === :$
        if in_quote_context  # This $ is simply interpolating out of the quote
            # Now, we're out of the quote, so any _further_ $ is ours.
            in_quote_context = false
        else
            newarg = gensym()
            push!(letargs, :($(esc(newarg)) = $(esc(expr.args[1]))))
            return newarg  # Don't recurse into the lifted $() exprs
        end
    elseif expr.head === :quote
        in_quote_context = true   # Don't try to lift $ directly out of quotes
    elseif expr.head === :macrocall
        return expr  # Don't recur into macro calls, since some other macros use $
    end
    for (i, e) in enumerate(expr.args)
        expr.args[i] = _lift_one_interp_helper(e, in_quote_context, letargs)
    end
    expr
end

# Copied from base rather than calling it directly because who knows if it'll change in the future
replace_linenums!(ex, ln::LineNumberNode) = ex
function replace_linenums!(ex::Expr, ln::LineNumberNode)
    if ex.head === :block || ex.head === :quote
        # replace line number expressions from metadata (not argument literal or inert) position
        map!(ex.args, ex.args) do @nospecialize(x)
            isa(x, Expr) && x.head === :line && length(x.args) == 1 && return Expr(:line, ln.line)
            isa(x, Expr) && x.head === :line && length(x.args) == 2 && return Expr(:line, ln.line, ln.file)
            isa(x, LineNumberNode) && return ln
            return x
        end
    end
    # preserve any linenums inside `esc(...)` guards
    if ex.head !== :escape
        for subex in ex.args
            subex isa Expr && replace_linenums!(subex, ln)
        end
    end
    return ex
end

end # module Internals
