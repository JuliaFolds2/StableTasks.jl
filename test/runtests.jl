using Test, StableTasks
using StableTasks: @spawn, @spawnat, @fetch, @fetchfrom

if isdefinded(Threads, :maxthreadid)
    maxthreadid() = Threads.maxthreadid()
else
    maxthreadid() = Threads.nthreads()
end

@testset "Type stability" begin
    @test 2 == @inferred fetch(@spawn 1 + 1)
    t = @eval @spawn inv([1 2 ; 3 4])
    @test inv([1 2 ; 3 4]) == @inferred fetch(t)

    @test 2 == @inferred fetch(@spawn :interactive 1 + 1)
    t = @eval @spawn :interactive inv([1 2 ; 3 4])
    @test inv([1 2 ; 3 4]) == @inferred fetch(t)

    s = :default
    @test 2 == @inferred fetch(@spawn s 1 + 1)
    t = @eval @spawn $(QuoteNode(s)) inv([1 2 ; 3 4])
    @test inv([1 2 ; 3 4]) == @inferred fetch(t)

    @test 2 == @inferred fetch(@spawnat 1 1 + 1)
    t = @eval @spawnat maxthreadid() inv([1 2 ; 3 4])
    @test inv([1 2 ; 3 4]) == @inferred fetch(t)
end

@testset "API funcs" begin
    T = @spawn rand(Bool)
    @test isnothing(wait(T))
    @test istaskdone(T)
    @test istaskfailed(T) == false
    @test istaskstarted(T)
    r = Ref(0)
    @sync begin
        @spawn begin
            sleep(5)
            r[] = 1
        end
        @test r[] == 0
    end
    @test r[] == 1

    T = @spawnat 1 rand(Bool)
    @test isnothing(wait(T))
    @test istaskdone(T)
    @test istaskfailed(T) == false
    @test istaskstarted(T)
    @test fetch(@spawnat 1 Threads.threadid()) == 1
    r = Ref(0)
    @sync begin
        @spawnat 1 begin
            sleep(5)
            r[] = 1
        end
        @test r[] == 0
    end
    @test r[] == 1

    @test @fetch(3+3) == 6
    @test @fetchfrom(1, Threads.threadid()) == 1
end
