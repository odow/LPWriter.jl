# LPWriter.jl

[![Build Status](https://travis-ci.org/odow/LPWriter.jl.svg?branch=master)](https://travis-ci.org/odow/LPWriter.jl)

[![codecov.io](http://codecov.io/github/odow/LPWriter.jl/coverage.svg?branch=master)](http://codecov.io/github/odow/LPWriter.jl?branch=master)

This package is not registered. Use `Pkg.clone("https://github.com/odow/LPWriter.jl")` to install.

The `LPWriter.jl` package is a pure Julia light-weight implementation of an [LP
file](http://lpsolve.sourceforge.net/5.0/CPLEX-format.htm) writer.

It has a single, user-facing, un-exported function.

```julia
LPWriter.write(io::IO,
    A::AbstractMatrix,       # the constraint matrix
    collb::Vector,           # vector of variable lower bounds
    colub::Vector,           # vector of variable upper bounds
    c::Vector,               # vector containing variable objective coefficients
    rowlb::Vector,           # constraint lower bounds
    rowub::Vector,           # constraint upper bounds
    sense::Symbol,           # model sense
    colcat::Vector{Symbol},  # constraint types
    sos::Vector{Tuple{Int, Vector{Int}, Vector{Float64}}}, # SOS information
    Q::AbstractMatrix,       #  Quadratic objective 0.5 * x' Q x
    modelname::AbstractString = "LPWriter_jl",  # LP model name
    colnames::Vector{String}  = ["V$i" for i in 1:length(c)],    # variable names
    rownames::Vector{String}  = ["C$i" for i in 1:length(rowub)] # constraint names
)
```

Limitations:
 - `sense` must be `:Min` or `:Max`
 - Quadratic objectives are unsupported
 - Only Integer (colcat = `:Int`), Binary (colcat = `:Bin`) and Continuous (colcat = `:Cont`)
    variables are supported.

SOS are given by the Tuple `Tuple{Int, Vector{Int}, Vector{Float64}}`
where the first index is either `1` (for SOS of type I) or `2` (for SOS of type II).
The second index a list of the indices of the columns in the constraint matrix
corresponding to the variables in the SOS set. The third index defines an ordering on
the indices.
