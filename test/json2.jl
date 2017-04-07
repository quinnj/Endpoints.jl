type B
    id::Int
    name::String
end

import Base.==
==(a::B, b::B) = a.id == b.id && a.name == b.name

type A
    int8::Int8
    int::Int
    float::Float64
    str::String
    nullint::Nullable{Int}
    nullnullint::Nullable{Int}
    nullstr::Nullable{String}
    nullnullstr::Nullable{String}
    void::Void
    truebool::Bool
    falsebool::Bool
    b::B

    ints::Vector{Int}
    emptyarray::Vector{Int}
type E
    bs::Vector{B}
    dict::Dict{String,Int}
    emptydict::Dict{String,Int}
end

b1 = B(1, "harry")
b2 = B(2, "hermione")
b3 = B(3, "ron")

a = A(0, -1, 3.14, "string \\\" w/ escaped double quote", Nullable(4), Nullable{Int}(),
        Nullable("null string"), Nullable{String}(), nothing, true, false, b1, [1,2,3], Int[], [b2, b3],
        Dict("1"=>1, "2"=>2), Dict{String,Int}())

io = IOBuffer()
Endpoints.JSON2.write(io, a)
seekstart(io)
a2 = Endpoints.JSON2.read(A, io)

@test a.int8 == a2.int8
@test a.int == a2.int
@test a.float == a2.float
@test a.str == a2.str
@test get(a.nullint) == get(a2.nullint)
@test isnull(a.nullnullint) && isnull(a2.nullnullint)
@test get(a.nullstr) == get(a2.nullstr)
@test isnull(a.nullnullstr) && isnull(a2.nullnullstr)
@test a.void == a2.void
@test a.truebool == a2.truebool
@test a.falsebool == a2.falsebool
@test a.b == a2.b
@test a.ints == a2.ints
@test a.emptyarray == a2.emptyarray
@test a.bs == a2.bs
@test a.dict == a2.dict
@test a.emptydict == a2.emptydict
