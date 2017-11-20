_nnz(Q::AbstractMatrix) = length(Q)
_nnz(Q::SparseMatrixCSC) = nnz(Q)
function write(io::IO,
    A::AbstractMatrix,       # the constraint matrix
    collb::Vector,  # vector of variable lower bounds
    colub::Vector,  # vector of variable upper bounds
    c::Vector,      # vector containing variable objective coefficients
    rowlb::Vector,  # constraint lower bounds
    rowub::Vector,  # constraint upper bounds
    sense::Symbol,           # model sense
    colcat::Vector{Symbol},  # constraint types
    sos::Vector{SOS},        # SOS information
    Q::AbstractMatrix,      #  Quadratic objectives 0.5 * x' Q x
    modelname::AbstractString="MPSWriter_jl",  # MPS model name
    colnames::Vector{String} = ["V$i" for i in 1:length(c)],
    rownames::Vector{String} = ["C$i" for i in 1:length(rowub)]
)
    for (i, cname) in enumerate(colnames)
        if !verifyname(cname)
            colnames[i] = correctname(cname)
        end
    end
    for (i, rname) in enumerate(rownames)
        if !verifyname(rname)
            rownames[i] = correctname(rname)
        end
    end
    if _nnz(Q) > 0
        error("LP writer does not support Quadratic objective")
    end
    if sense != :Max && sense != :Min
        error("sense must be either :Min or :Max. Currently sense =$(sense).")
    end

    if sense == :Max
        println(io,"Maximize")
    else
        println(io,"Minimize")
    end

    print_objective!(io, c, colnames)
    print_constraints!(io, A, rowlb, rowub, colnames, rownames)
    print_sos!(io, sos, colnames)
    print_bounds!(io, collb, colub, colnames)
    print_category!(io, colcat, colnames)

    println(io, "End")
end

function print_objective!(io, c, colnames)
    print(io, "obj: ")
    sp_c = sparse(c)
    is_first = true
    for (col, val) in zip(sp_c.nzind, sp_c.nzval)
        print_variable_coefficient!(io, val, colnames[col], is_first)
        is_first = false
    end
    println(io, "")
end

function print_variable_coefficient!(io, val, name, is_first)
    if is_first
        print_shortest(io, val)
    else
        print(io, val < 0?" - ":" + ")
        print_shortest(io, abs(val))
    end
    print(io, " $(name)")
end

function getrowsense{T1 <: Real, T2<: Real}(rowlb::Vector{T1}, rowub::Vector{T2})
    @assert length(rowlb) == length(rowub)
    row_sense = Array{Symbol}(length(rowub))
    hasranged = false
    for r=1:length(rowlb)
        @assert rowlb[r] <= rowub[r]
    	if (rowlb[r] == -Inf && rowub[r] != Inf) || (rowlb[r] == typemin(eltype(rowlb)) && rowub[r] != typemax(eltype(rowub)))
    		row_sense[r] = :(<=) # LE constraint
    	elseif (rowlb[r] != -Inf && rowub[r] == Inf)  || (rowlb[r] != typemin(eltype(rowlb)) && rowub[r] == typemax(eltype(rowub)))
    		row_sense[r] = :(>=) # GE constraint
    	elseif rowlb[r] == rowub[r]
    		row_sense[r] = :(==) # Eq constraint
        elseif (rowlb[r] == -Inf && rowub[r] == Inf)
            error("Cannot have a constraint with no bounds")
    	else
            row_sense[r] = :ranged
            hasranged = true
    	end
    end
    row_sense, hasranged
end

function print_constraints!(io, A, rowlb, rowub, colnames, rownames)
    println(io, "Subject To")
    row_sense, hasranged = getrowsense(rowlb, rowub)
    if hasranged
        error("LP Writer does not support ranged constraints")
    end

    sA = sparse(A)' # so we can iterate over rows instead of columns

    cols, vals = rowvals(sA), nonzeros(sA)
    for row in 1:length(rowlb)
        is_first = true
        print(io, "$(rownames[row]): ")
        for j in nzrange(sA, row)
            print_variable_coefficient!(io, vals[j], colnames[cols[j]], is_first)
            is_first = false
        end
        if row_sense[row] == :(>=)
            println(io, " $(row_sense[row]) $(rowlb[row])")
        else
            println(io, " $(row_sense[row]) $(rowub[row])")
        end
    end
end

function print_bounds!(io, collb, colub, colnames)
    println(io, "Bounds")
    for (i, (lb, ub, name)) in enumerate(zip(collb, colub, colnames))
        if lb == -Inf && ub == +Inf
            println(io, "$(name) free")
        else
            if lb == -Inf
                print(io, "-inf")
            else
                print_shortest(io, lb)
            end
             print(io, " <= $(name) <= ")
            if ub == Inf
                print(io, "+inf")
            else
                print_shortest(io, ub)
            end
            println(io)
        end
    end
end

function print_category!(io, colcat, colnames)
    if any(colcat .== :SemiCont) || any(colcat .== :SemiInt)
        error("The LP file writer does not currently support semicontinuous or semi-integer variables")
    end
    println(io, "General")# Integer
    for (cat, name) in zip(colcat, colnames)
        if cat == :Int
            println(io, "$(name)")
        end
    end
    println(io, "Binary")
    for (cat, name) in zip(colcat, colnames)
        if cat == :Bin
            println(io, "$(name)")
        end
    end
end

function print_sos!(io, sosconstraints::Vector{SOS}, colnames)
    for (i, sos) in enumerate(sosconstraints)
        print_sos!(io, string("csos", i), sos, colnames)
    end
end
function print_sos!(io, rowname::String, sos::SOS, colnames)
    # format
    # c5: S1:: col_1:1 y:2 z:3
    print(io, rowname, ": ")
    print(io, "S", string(sos[1]), "::")
    for (index, weight) in zip(sos[2], sos[3])
        print(io, " ", colnames[index], ":")
        print_shortest(io, weight)
    end
    println(io)
end
