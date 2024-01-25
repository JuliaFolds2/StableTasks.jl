using Test, StableTasks
using StableTasks: @spawn

@testset "Type stability" begin
    @test 2 ==@inferred fetch(@spawn 1 + 1)
    t = @eval @spawn inv([1 2 ; 3 4])
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
end
