@testset "Bounds" begin
    @testset "Infinity" begin
        @test LPWriter.parsefloat("-inf") == -Inf
        @test LPWriter.parsefloat("-iNf") == -Inf
        @test LPWriter.parsefloat("-iNfinity") == -Inf
        @test LPWriter.parsefloat("+inf") == Inf
        @test LPWriter.parsefloat("+iNf") == Inf
        @test LPWriter.parsefloat("+iNfinity") == Inf
    end
    data = LPWriter.newdatastore()
    for (line, lb, ub) in [
            ("x free", -Inf, Inf),
            ("x <= 1.1", -Inf, 1.1),
            ("x < 1.2", -Inf, 1.2),
            ("x >= 1.3", 1.3, Inf),
            ("x > 1.4", 1.4, Inf),
            ("x = 1.5", 1.5, 1.5),
            ("x == 1.6", 1.6, 1.6),
            ("0 < x < 1.7", 0.0, 1.7),
            ("0 <= x <= 1.7", 0.0, 1.7),
            ("0 < x <= 1.7", 0.0, 1.7),
            ("0 <= x < 1.7", 0.0, 1.7),
            ("1.2 > x > 0.1", 0.1, 1.2),
            ("1.2 >= x >= 0.1", 0.1, 1.2),
            ("1.2 > x >= 0.1", 0.1, 1.2),
            ("1.2 >= x > 0.1", 0.1, 1.2),
            ("5.5 <= x <= +inf", 5.5, Inf)
        ]
        LPWriter.parsesection!(Val{:bounds}, data, line)
        @test data[:collb][1] == lb
        @test data[:colub][1] == ub
    end

    for line in [
            "x not free",
            "x notfree",
            "1.1 > x",
            "> x 1.1",
            "x free < 1",
            "x <> 1.4",
            "x",
            "0 < 1 < x < 1.6",
            "0 < x > 1.6"
        ]
        @test_throws Exception LPWriter.parsesection!(Val{:bounds}, data, line)
    end
end

@testset "Variable type" begin
    for (val, cat) in [(Val{:integer}, :Int), (Val{:binary}, :Bin)]
        @testset "$cat" begin
            data = LPWriter.newdatastore()
            LPWriter.addnewvariable!(data, "A")
            LPWriter.addnewvariable!(data, "B")
            LPWriter.addnewvariable!(data, "C")

            @test all(data[:colcat] .== :Cont)

            LPWriter.parsesection!(val, data, "A")
            @test data[:colcat][1] == cat

            LPWriter.parsesection!(val, data, "B C")
            @test all(data[:colcat]  .== cat)

            LPWriter.parsesection!(val, data, "xy")
            @test all(data[:colcat]  .== cat)
            @test length(data[:colcat]) == 4
        end
    end
end

@testset "Objective" begin
    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:obj}, data, "obj: -1 x + 1 y")
    @test data[:c] == [1.0, -1.0]

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:obj}, data, "-1 x + 1 y")
    @test data[:c] == [1.0, -1.0]

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:obj}, data, "+ 1 x + 1 y")
    @test data[:c] == [1.0, 1.0]

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:obj}, data, "+ 1 x - 2.3 y")
    @test data[:c] == [-2.3, 1.0]

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:obj}, data, "")
    @test data[:c] == Float64[]

    @test_throws Exception LPWriter.parsesection!(Val{:obj}, data, "-1 x + x y")
    @test_throws Exception LPWriter.parsesection!(Val{:obj}, data, "-1 x * 1 y")
end
@testset "Constraints" begin
    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:constraints}, data, "C1: 1.2 x - 2.4 y <= 1")
    @test data[:A].i == [1, 1]
    @test data[:A].j == [1, 2]
    @test data[:A].v == [-2.4, 1.2]
    @test data[:rowlb][1] == -Inf
    @test data[:rowub][1] == 1.0

    @test_throws Exception LPWriter.parsesection!(Val{:constraints}, data, "C1: a x - 2.4 y <= 1")
    @test_throws Exception LPWriter.parsesection!(Val{:constraints}, data, "C1: 1 x * 2.4 y <= 1")

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:constraints}, data, "C1: 1 x + 2.4 y")
    @test_throws Exception LPWriter.parsesection!(Val{:constraints}, data, "C1: 1 x + 2.4 y <= 1")

    @test_throws Exception LPWriter.parsesection!(Val{:constraints}, data, "C1: ")

    data = LPWriter.newdatastore()
    LPWriter.parsesection!(Val{:constraints}, data, "C1: -1.2 x - 2.4 y = 1")
    @test data[:A].i == [1, 1]
    @test data[:A].j == [1, 2]
    @test data[:A].v == [-2.4, -1.2]
    @test data[:rowlb][1] == 1.0
    @test data[:rowub][1] == 1.0

end

@testset "Model 1" begin
    A, collb, colub, c, rowlb, rowub, sense, colcat, sos, Q, modelname, colnames, rownames = LPWriter.readlp("model1.lp")

    variable_permutation = [5, 4, 1, 2, 3, 7, 6, 8]

    @test A == permute(sparse([1, 2, 3, 4, 4, 4],[1, 2, 3, 5,6,7], [1, 1, 1, 1, 1, 1], 4, 8), 1:4, variable_permutation)
    @test collb == [-Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0][variable_permutation]
    @test colub == [3, 3, 3, Inf, 1, 1, 1, 1][variable_permutation]
    @test c == [0,0,0,-1,1,0,0,0][variable_permutation]
    @test rowlb == [0, 2, -Inf, -Inf]
    @test rowub == [Inf, Inf, 2.5, 1]
    @test sense == :Max
    @test colcat == [:Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin][variable_permutation]
    @test sos == LPWriter.SOS[]
    # @test Q == Array{Float64}(0,0)
    # @test modelname == "TestModel"
    @test colnames == ["V$(i)" for i in variable_permutation]
    @test rownames == ["CON$i" for i in 1:4]
end

@testset "Model 2" begin
    A, collb, colub, c, rowlb, rowub, sense, colcat, sos, Q, modelname, colnames, rownames = LPWriter.readlp("model2.lp")

    variable_permutation = [5, 4, 1, 2, 3, 7, 6, 8]

    @test A == permute(sparse([1, 2, 3, 4, 4, 4],[1, 2, 3, 5,6,7], [1, 1, 1, 1, 1, 1], 4, 8), 1:4, variable_permutation)
    @test collb == [-Inf, -Inf, -Inf, 5.5, 0, 0, 0, 0][variable_permutation]
    @test colub == [3, 3, 3, Inf, 1, 1, 1, 1][variable_permutation]
    @test c == [0,0,0,-1,1,0,0,0][variable_permutation]
    @test rowlb == [0, 2, -Inf, -Inf]
    @test rowub == [Inf, Inf, 2.5, 1]
    @test sense == :Min
    @test colcat == [:Cont, :Cont, :Cont, :Int, :Cont, :Cont, :Cont, :Bin][variable_permutation]
    @test sos == LPWriter.SOS[]
    # @test Q == Array{Float64}(0,0)
    # @test modelname == "TestModel"
    @test colnames == ["V$(i)" for i in variable_permutation]
    @test rownames == ["CON$i" for i in 1:4]
end

@testset "Tricky" begin
    A, collb, colub, c, rowlb, rowub, sense, colcat, sos, Q, modelname, colnames, rownames = LPWriter.readlp("model1_tricky.lp")

    variable_permutation = [4, 5, 1, 2, 3, 6, 7, 8]

    @test A == permute(sparse([1, 2, 3, 4, 4, 4],[1, 2, 3, 5,6,7], [1, 1, 1, 1, 1, 1], 4, 8), 1:4, variable_permutation)
    @test collb == [-Inf, -Inf, -3, 5.5, 1, -Inf, 0, 0][variable_permutation]
    @test colub == [3, 3, Inf, Inf, 1, Inf, 1, 1][variable_permutation]
    @test c == [0,0,0,-1,1,0,0,0][variable_permutation]
    @test rowlb == [0, 2, -Inf, -Inf]
    @test rowub == [Inf, Inf, 2.5, 1]
    @test sense == :Max
    @test colcat == [:Cont, :Cont, :Cont, :Int, :Int, :Int, :Cont, :Bin][variable_permutation]
    @test sos == LPWriter.SOS[]
    # @test Q == Array{Float64}(0,0)
    # @test modelname == "TestModel"
    cnames = ["V$(i)" for i in variable_permutation]
    cnames[1] = "Var4"
    @test colnames == cnames
    @test rownames == ["CON1", "R2", "CON3", "CON4"]
end
