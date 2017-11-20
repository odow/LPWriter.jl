@testset "correctname" begin
    # not very complete. Need better way to test
    @test LPWriter.correctname(repeat("x", 17)) == repeat("x", 16)
    @test LPWriter.correctname(".x") == "x"
    @test LPWriter.correctname("0x") == "x"
    @test LPWriter.correctname("x^") == "x"
    @test LPWriter.correctname("x*ds") == "xds"
    @test LPWriter.correctname("x*ds[1]") == "xds1"
    @test LPWriter.correctname("ex*ds[1]") == "xds1"
    @test LPWriter.correctname("Ex*ds[1]") == "xds1"
end

@testset "verifyname" begin
    # not very complete. Need better way to test
    @test LPWriter.verifyname("x")
    @test LPWriter.verifyname(repeat("x", 16))
    @test LPWriter.verifyname(repeat("x", 17)) == false
    @test LPWriter.verifyname(".x") == false
    @test LPWriter.verifyname("0x") == false
    @test LPWriter.verifyname("exe") == false
    @test LPWriter.verifyname("ExE") == false
    @test LPWriter.verifyname("x^") == false
    @test LPWriter.verifyname("x*ds") == false
end

@testset "print_objective!" begin
    io = IOBuffer()

    LPWriter.print_objective!(io, [0, 1, -2.3, 4e3], ["A", "B", "C", "x"])
    @test String(take!(io)) == "obj: 1 B - 2.3 C + 4e3 x\n"

    close(io)
end

@testset "print_variable_coefficient!" begin
    io = IOBuffer()

    LPWriter.print_variable_coefficient!(io, -1.3, "x", true)
    @test String(take!(io)) == "-1.3 x"

    LPWriter.print_variable_coefficient!(io, 1.3, "x", true)
    @test String(take!(io)) == "1.3 x"

    LPWriter.print_variable_coefficient!(io, -1.3, "x", false)
    @test String(take!(io)) == " - 1.3 x"

    LPWriter.print_variable_coefficient!(io, 1.3, "x", false)
    @test String(take!(io)) == " + 1.3 x"

    close(io)
end

@testset "getrowsense" begin
    # LE, GE, Eq, Ranged
    row_sense, hasranged = LPWriter.getrowsense([-Inf, 0.], [0., Inf])
    @test row_sense == [:(<=), :(>=)]
    @test hasranged == false

    row_sense, hasranged = LPWriter.getrowsense([1., -1.], [1., 1.])
    @test row_sense == [:(==), :ranged]
    @test hasranged == true

    @test_throws Exception LPWriter.getrowsense([1.], [1., 1.])
    @test_throws Exception LPWriter.getrowsense([-Inf], [Inf])
end

@testset "print_constraints!" begin
    io = IOBuffer()

    LPWriter.print_constraints!(io, [1 -1], [-Inf], [1.0], ["x", "y"], ["r1"])
    @test String(take!(io)) == "Subject To\nr1: 1 x - 1 y <= 1.0\n"

    LPWriter.print_constraints!(io, [1 0 -1], [-1.2], [Inf], ["x", "z", "y"], ["r1"])
    @test String(take!(io)) == "Subject To\nr1: 1 x - 1 y >= -1.2\n"

    @test_throws Exception LPWriter.print_constraints!(io, [1 -1], [-1.2], [1], ["x", "y"], ["r1"])

    close(io)
end

@testset "print_bounds!" begin
    io = IOBuffer()

    LPWriter.print_bounds!(io, [-Inf, -Inf, -1, -1, 0, 1], [Inf, 2, Inf, 3, Inf, Inf], ["A", "B", "C", "D", "E", "F"])

    @test String(take!(io)) == "Bounds\nA free\n-inf <= B <= 2\n-1 <= C <= +inf\n-1 <= D <= 3\n0 <= E <= +inf\n1 <= F <= +inf\n"

    close(io)
end

@testset "print_category!" begin
    io = IOBuffer()

    @test_throws Exception LPWriter.print_category!(io, [:Cont, :SemiCont], ["A", "B"])
    @test_throws Exception LPWriter.print_category!(io, [:Cont, :SemiInt], ["A", "B"])

    LPWriter.print_category!(io, [:Cont, :Int], ["A", "B"])
    @test String(take!(io)) == "General\nB\nBinary\n"

    LPWriter.print_category!(io, [:Cont, :Bin], ["A", "B"])
    @test String(take!(io)) == "General\nBinary\nB\n"

    LPWriter.print_category!(io, [:Cont, :Bin, :Cont, :Int], ["A", "B", "C", "D"])
    @test String(take!(io)) == "General\nD\nBinary\nB\n"

    close(io)
end

@testset "print_sos!" begin
    io = IOBuffer()
    LPWriter.print_sos!(io, "csos1", (1, [1,2], [2.0, 4.0]), ["V1", "V2"])
    @test String(take!(io)) == "csos1: S1:: V1:2 V2:4\n"
    LPWriter.print_sos!(io, "anyname", (2, [2,3], [2.0, 4.0]), ["V1", "V2", "X"])
    @test String(take!(io)) == "anyname: S2:: V2:2 X:4\n"
    close(io)
end

@testset "writelp" begin

    @testset "Quadratic Objectives" begin
        io = IOBuffer()
        @test_throws Exception LPWriter.writelp(io,
            Array{Float64}(0,0), [], [], [], [], [], :Max, Symbol[],
            LPWriter.SOS[], [1 0; 0 1])
        close(io)
    end

    @testset "Bad sense" begin
        io = IOBuffer()
        @test_throws Exception LPWriter.writelp(io,
            Array{Float64}(0,0), [], [], [], [], [], :maximum, Symbol[],
            LPWriter.SOS[], Array{Float64}(0,0))
        close(io)
    end

    # @testset "Special Ordered Sets" begin
    #     io = IOBuffer()
    #     @test_throws Exception LPWriter.writelp(io,
    #         Array{Float64}(0,0), [], [], [], [], [], :Max, Symbol[],
    #         LPWriter.SOS[LPWriter.SOS(2, [5,6,7], [1,2,3])], Array{Float64}(0,0))
    #     close(io)
    # end

    @testset "writelp" begin
        io = IOBuffer()
        LPWriter.writelp(io,
        [
        1 0 0 0 0 0 0 0;
        0 1 0 0 0 0 0 0;
        0 0 1 0 0 0 0 0;
        0 0 0 0 1 1 1 0
        ],
        [-Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0],
        [3, 3, 3, Inf, 1, 1, 1, 1],
        [0,0,0,-1,1,0,0,0],
        [0, 2, -Inf, -Inf],
        [Inf, Inf, 2.5, 1],
        :Max,
        [:Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin],
        LPWriter.SOS[
            (1, [1,3,5], [1.0, 2.0, 3.0]),
            (2, [2,4,5], [2.0, 1.0, 2.5])
        ],
        Array{Float64}(0,0),
        "TestModel",
        ["V$i" for i in 1:8],
        ["CON$i" for i in 1:4]
        )
        MODEL1 = replace(readstring(joinpath(@__DIR__, "model1.lp")), "\r\n", "\n")
        @test String(take!(io)) == MODEL1
        close(io)
    end

    @testset "writelp2" begin
        io = IOBuffer()
        LPWriter.writelp(io,
        [
        1 0 0 0 0 0 0 0;
        0 1 0 0 0 0 0 0;
        0 0 1 0 0 0 0 0;
        0 0 0 0 1 1 1 0
        ],
        [-Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0],
        [3, 3, 3, Inf, 1, 1, 1, 1],
        [0,0,0,-1,1,0,0,0],
        [0, 2, -Inf, -Inf],
        [Inf, Inf, 2.5, 1],
        :Min,
        [:Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin],
        LPWriter.SOS[],
        Array{Float64}(0,0),
        "TestModel",
        ["V[$(i)]" for i in 1:8],
        ["$(i)CON$i" for i in 1:4]
        )
        MODEL2 = replace(readstring(joinpath(@__DIR__, "model2.lp")), "\r\n", "\n")
        @test String(take!(io)) == MODEL2
        close(io)
    end

end
