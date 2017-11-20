const sense_alias = Dict(
"max"      => :Max,
"maximize" => :Max,
"maximise" => :Max,
"maximum"  => :Max,
"min"      => :Min,
"minimize" => :Min,
"minimise" => :Min,
"minimum"  => :Min
)

const subject_to_alias = ["subject to", "such that", "st", "s.t."]

# a list of section keywords in lower-case
const KEYWORDS = Dict(
    "max"      => Val{:obj},
    "maximize" => Val{:obj},
    "maximise" => Val{:obj},
    "maximum"  => Val{:obj},
    "min"      => Val{:obj},
    "minimize" => Val{:obj},
    "minimise" => Val{:obj},
    "minimum"  => Val{:obj},

    "subject to" => Val{:constraints},
    "such that"  => Val{:constraints},
    "st"         => Val{:constraints},
    "s.t."       => Val{:constraints},

    "bounds" => Val{:bounds},
    "bound"  => Val{:bounds},

    "gen"      => Val{:integer},
    "general"  => Val{:integer},
    "generals" => Val{:integer},

    "bin"      => Val{:binary},
    "binary"   => Val{:binary},
    "binaries" => Val{:binary},

    "end"      => Val{:quit}
)

const COMMENT_REG = r"(.*?)\\(.*)"
function stripcomment(line::String)
    if contains(line, "\\")
        m = match(COMMENT_REG, line)
        return strip(String(m[1]))
    else
        return strip(line)
    end
end

immutable TempSparseMatrix
    i::Vector{Int}
    j::Vector{Int}
    v::Vector{Float64}
end
TempSparseMatrix() = TempSparseMatrix(Int[], Int[], Float64[])
Base.sparse(m::TempSparseMatrix, nr::Int, nc::Int) = sparse(m.i, m.j, m.v, nr, nc)

newdatastore() = Dict(
    :A => TempSparseMatrix(),
    :collb => Float64[],
    :colub => Float64[],
    :c => Float64[],
    :rowlb => Float64[],
    :rowub => Float64[],
    :sense => :Min,
    :colcat => Symbol[],
    :sos => SOS[],
    :Q => TempSparseMatrix(),
    :modelname => "",
    :colnames => String[],
    :rownames => String[],
    :open_constraint => false
)
setsense!(T, data, line) = nothing
function setsense!(::Type{Val{:obj}}, data, line)
    data[:sense] = sense_alias[lowercase(line)]
end
function read(filename::String)
    data = newdatastore()
    open(filename, "r") do io
        section = :none
        while !eof(io)
            line = stripcomment(readline(io))
            if line == "" # skip blank lines
                continue
            end
            if haskey(KEYWORDS, lowercase(line)) # section has changed
                section = KEYWORDS[lowercase(line)]
                setsense!(section, data, line)
                continue
            end
            parsesection!(section, data, line)
        end
    end
    return sparse(data[:A], length(data[:rownames]), length(data[:colnames])),
        data[:collb],
        data[:colub],
        data[:c],
        data[:rowlb],
        data[:rowub],
        data[:sense],
        data[:colcat],
        data[:sos],
        sparse(data[:Q], length(data[:rownames]), length(data[:colnames])),
        data[:modelname],
        data[:colnames],
        data[:rownames]
end

parsesection!(::Type{Val{:quit}}, data, line) = error("Corrupted LP File. You have the lne $(line) after an end.")

function parsesection!(::Type{Val{:obj}}, data, line)
    # okay so line should be the start of the objective
    if contains(line, ":")
        # throw away name
        m = match(r"(.*?)\:(.*)", line)
        line = String(m[2])
    end
    tokens = tokenize(line)
    if length(tokens) == 0 # no objective
        return
    end
    # tokens should be in order (+/-) (numeric) (variable) ...
    while length(tokens) > 0
        variable = String(pop!(tokens))
        idx = getvariableindex!(data, variable) # catch in here for malformed variables
        coef_token = pop!(tokens)
        try
            coefficient = parse(Float64, coef_token)
        catch
            error("Unable to parse objective. Expected numeric coefficient. Got $(coef_token)")
        end
        if length(tokens) > 0
            _sign = pop!(tokens)
            if _sign == "-"
                coefficient *= -1
            elseif _sign == "+"
            else
                error("Unable to parse objective due to bad operator: $(_sign) $(line)")
            end
        end
        data[:c][idx] = coefficient
    end
end

const constraintsense = Dict(
    "<"  => :le,
    "<=" => :le,
    "="  => :eq,
    "==" => :eq,
    ">"  => :ge,
    ">=" => :ge,
)

function parseconstraintcoefficients!(data, line, tokens, rowidx)
    # tokens should be in order (+/-) (numeric) (variable) ...
    while length(tokens) > 0
        variable = String(pop!(tokens))
        idx = getvariableindex!(data, variable) # catch in here for malformed variables
        coef_token = pop!(tokens)
        try
            coefficient = parse(Float64, coef_token)
        catch
            error("Unable to parse constraint $(line). Expected numeric coefficient. Got $(coef_token)")
        end
        if length(tokens) > 0
            _sign = pop!(tokens)
            if _sign == "-"
                coefficient *= -1
            elseif _sign == "+"
            else
                error("Unable to parse objective due to bad operator: $(_sign) $(line)")
            end
        end
        push!(data[:A].i, rowidx)
        push!(data[:A].j, idx)
        push!(data[:A].v, coefficient)
    end
end

function parsesos!(data, line)
    tokens = tokenize(line)
    if length(tokens) < 3
        error(string("Malformed SOS constraint: ", line))
    end
    if tokens[2] == "S1::"
        order = 1
    elseif tokens[2] == "S2::"
        order = 2
    else
        error("SOS of type $(tokens[2]) not recognised")
    end
    names   = String[]
    weights = Float64[]
    for token in tokens[3:end]
        items = split(token, ":")
        if length(items) != 2
            error(string("Invalid sequence: ", token))
        end
        push!(names, String(items[1]))
        push!(weights, parsefloat(String(items[2])))
    end
    indices = Int[]
    for name in names
        idx = findfirst(data[:colnames], name)
        if idx == 0
            push!(data[:colnames], name)
            push!(indices, length(data[:colnames]))
        else
            push!(indices, idx)
        end
    end
    push!(data[:sos], (order, indices, weights))
end

function parsesection!(::Type{Val{:constraints}}, data, line)
    if match(r" S([0-9]):: ", line) != nothing
        # it's an SOS constraint
        parsesos!(data, line)
        return
    end
    if data[:open_constraint] == false
        push!(data[:rownames], "R$(length(data[:rownames]) + 1)")
        push!(data[:rowlb], -Inf)
        push!(data[:rowub], Inf)
    end
    if contains(line, ":")
        if data[:open_constraint] == true
            error("Malformed constraint $(line). Is the previous one valid?")
        end
        # throw away name
        m = match(r"(.*?)\:(.*)", line)
        data[:rownames][end] = String(m[1])
        line = String(m[2])
    end
    data[:open_constraint] = true

    tokens = tokenize(line)
    if length(tokens) == 0 # no entries
        return
    elseif length(tokens) >= 2 && haskey(constraintsense, tokens[end-1])# test if constraint ends this line
        rhs = parsefloat(pop!(tokens))
        sym = pop!(tokens)
        if constraintsense[sym] == :le
            data[:rowub][end] = rhs
        elseif constraintsense[sym] == :ge
            data[:rowlb][end] = rhs
        elseif constraintsense[sym] == :eq
            data[:rowlb][end] = rhs
            data[:rowub][end] = rhs
        end
        data[:open_constraint] = false # finished
    end
    parseconstraintcoefficients!(data, line, tokens, length(data[:rownames]))
end


function getvariableindex!(data, v)
    i = findfirst(data[:colnames], v)
    if i == 0
        if !verifyname(v)
            error("Invalid variable name $v")
        end
        addnewvariable!(data, v)
        return length(data[:colnames])
    end
    return i
end

function addnewvariable!(data, name)
    push!(data[:collb], -Inf)
    push!(data[:colub],  Inf)
    push!(data[:c], 0)
    push!(data[:colcat], :Cont)
    push!(data[:colnames], name)
end

function parsevariabletype!(data, line, cat)
    items = tokenize(line)
    for v in items
        i = getvariableindex!(data, v)
        data[:colcat][i] = cat
    end
end
parsesection!(::Type{Val{:integer}}, data, line) = parsevariabletype!(data, line, :Int)
parsesection!(::Type{Val{:binary}}, data, line)  = parsevariabletype!(data, line, :Bin)

function parsefloat(val::String)
    if lowercase(val) == "-inf" || lowercase(val) == "-infinity"
        return -Inf
    elseif lowercase(val) == "+inf" || lowercase(val) == "+infinity"
        return Inf
    else
        return parse(Float64, val)
    end
end
function tokenize(line)
    items = String.(split(line, " "))
    items[items .!= ""]
end
bounderror(line) = error("Unable to parse bound: $(line)")
function parsesection!(::Type{Val{:bounds}}, data, line)
    items = tokenize(line)
    v = ""
    lb = -Inf
    ub = Inf
    if length(items) == 5 # ranged bound
        v = items[3]
        if (items[2] == "<=" || items[2] == "<") &&  (items[4] == "<=" || items[4] == "<") # le
            lb = parsefloat(items[1])
            ub = parsefloat(items[5])
        elseif (items[2] == ">=" || items[2] == ">") &&  (items[4] == ">=" || items[4] == ">") # ge
            lb = parsefloat(items[5])
            ub = parsefloat(items[1])
        else
            bounderror(line)
        end
    elseif length(items) == 3 # one sided
        v = items[1]
        if items[2] == "<=" || items[2] == "<" # le
            ub = parsefloat(items[3])
        elseif items[2] == ">=" || items[2] == ">" # ge
            lb = parsefloat(items[3])
        elseif items[2] == "==" || items[2] == "=" # eq
            lb = ub = parsefloat(items[3])
        else
            bounderror(line)
        end
    elseif length(items) == 2 # free
        if items[2] != "free"
            bounderror(line)
        end
        v = items[1]
    else
        bounderror(line)
    end
    i = getvariableindex!(data, v)
    data[:collb][i] = lb
    data[:colub][i] = ub

end
