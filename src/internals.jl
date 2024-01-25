module Internals 

import StableTasks: @spawn, StableTask

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


macro spawn(ex)
    tp = QuoteNode(:default)

    letargs = Base._lift_one_interp!(ex)

    thunk = Base.replace_linenums!(:(()->($(esc(ex)))), __source__)
    var = esc(Base.sync_varname) # This is for the @sync macro which sets a local variable whose name is
                                 # the symbol bound to Base.sync_varname
                                 # I asked on slack and this is apparently safe to consider a public API
    quote
        let $(letargs...)
            f = $thunk
            T = Core.Compiler.return_type(f, Tuple{})
            ref = Ref{T}()
            f_wrap = () -> (ref[] = f(); nothing)
            task = Task(f_wrap)
            task.sticky = false
            if $(Expr(:islocal, var))
                put!($var, task) # Sync will set up a Channel, and we want our task to be in there.
            end
            schedule(task)
            StableTask(task, ref)
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
    for (i,e) in enumerate(expr.args)
        expr.args[i] = _lift_one_interp_helper(e, in_quote_context, letargs)
    end
    expr
end

end # module Internals
