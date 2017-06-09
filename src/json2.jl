module JSON2

macro repeat(N, expr)
    blk = esc(quote end)
    foreach(x->push!(blk.args, expr), 1:N)
    return blk
end

function write{T}(io::IO, obj::T)
    Base.write(io, '{')
    fields = nfields(T)
    for i = 1:fields
        Base.write(io, '"', fieldname(T, i), "\": ")
        write(io, getfield(obj, i)) # recursively call write
        i < fields && Base.write(io, ',')
    end
    Base.write(io, '}')
    return
end

# write Associative, AbstractArray, Number, String, Nullable, Bool, Tuple
function write{T <: Associative}(io::IO, obj::T)
    Base.write(io, '{')
    len = length(obj)
    i = 1
    for k in keys(obj)
        write(io, k) # recursive
        Base.write(io, ": ")
        write(io, obj[k]) # recursive
        i < len && Base.write(io, ',')
        i += 1
    end
    Base.write(io, '}')
    return
end

function write{T <: Union{AbstractArray,Tuple}}(io::IO, obj::T)
    # always written as single array
    Base.write(io, '[')
    len = length(obj)
    for i = 1:len
        write(io, obj[i]) # recursive
        i < len && Base.write(io, ',')
    end
    Base.write(io, ']')
    return
end

write(io::IO, obj::Number) = (Base.write(io, string(obj)); return)
write(io::IO, obj::AbstractString) = (Base.write(io, '"', obj, '"'); return)
write{T}(io::IO, obj::Nullable{T}) = (isnull(obj) ? Base.write(io, "null") : write(io, get(obj)); return)
write(io::IO, obj::Void) = (Base.write(io, "null"); return)
write(io::IO, obj::Bool) = (Base.write(io, obj ? "true" : "false"); return)

@inline function readbyte(from::Base.AbstractIOBuffer, ::Type{UInt8}=UInt8)
    @inbounds byte = from.data[from.ptr]
    from.ptr = from.ptr + 1
    return byte
end

@inline function peekbyte(from::Base.AbstractIOBuffer)
    @inbounds byte = from.data[from.ptr]
    return byte
end

function read{T}(::Type{T}, io::IOBuffer)
    _ = readbyte(io) # '{'
    fields = []
    for i = 1:length(fieldnames(T))
        _ = readuntil(io, ':') # read fieldname until start of fieldvalue
        _ = readbyte(io) # read ' '
        push!(fields, read(fieldtype(T, i), io)) # recursively reads until ',' or '}'
    end
    !eof(io) && readbyte(io)
    return T(fields...)
end

function read{K,V}(::Type{Dict{K,V}}, io::IOBuffer)
    c = readbyte(io) # '{'
    dict = Dict{K,V}()
    peekbyte(io) == CLOSE_CURLY_BRACE && return dict
    while true
        key = read(K, io)
        _ = readbyte(io) # read ' '
        dict[key] = read(V, io) # recursively reads until ',' or '}'
        c = peekbyte(io)
        (c == COMMA || c == CLOSE_CURLY_BRACE || eof(io)) && (!eof(io) && readbyte(io); break)
    end
    return dict
end

const CLOSE_CURLY_BRACE = UInt8('}')
const CLOSE_SQUARE_BRACE = UInt8(']')
const COMMA = UInt8(',')

function read{T <: AbstractArray}(::Type{T}, io::IOBuffer)
    c = readbyte(io) # '['
    eT = eltype(T)
    A = eT[]
    peekbyte(io) == CLOSE_SQUARE_BRACE && return A
    while true
        push!(A, read(eT, io)) # recursively reads until ',' or ']'
        c = peekbyte(io)
        (c == COMMA || c == CLOSE_CURLY_BRACE || eof(io)) && (!eof(io) && readbyte(io); break)
    end
    return A
end

# read Associative, AbstractArray, Number, String, Nullable, Bool, Tuple
const MINUS = UInt8('-')
const PLUS = UInt8('+')
const NEG_ONE = UInt8('0') - 0x01
const TEN = UInt8('9') + 0x01
const ZERO = UInt8('0')

function read{T <: Integer}(::Type{T}, io::IOBuffer)
    v = zero(T)
    b = readbyte(io)
    negative = false
    if b == MINUS # check for leading '-' or '+'
        negative = true
        b = readbyte(io, UInt8)
    elseif b == PLUS
        b = readbyte(io, UInt8)
    end
    while NEG_ONE < b < TEN
        v *= 10
        v += b - ZERO
        eof(io) && break
        b = readbyte(io, UInt8)
    end
    return ifelse(negative, -v, v)
end

const REF = Vector{Ptr{UInt8}}(1)

function read{T <: AbstractFloat}(::Type{T}, io::IOBuffer)
    v = zero(T)
    ptr = pointer(io.data) + position(io) - 1
    v = convert(T, ccall(:jl_strtod_c, Float64, (Ptr{UInt8}, Ptr{Ptr{UInt8}}), ptr, REF))
    io.ptr += REF[1] - ptr - 1
    !eof(io) && readbyte(io)
    return v
end

const BUF = IOBuffer()

function read(::Type{String}, io::IOBuffer)
    b = readbyte(io) # '"'
    b = readbyte(io)
    while b != UInt8('"')
        Base.write(BUF, b)
        b = readbyte(io)
        if b == UInt8('\\')
            Base.write(BUF, b, readbyte(io)) # escaped double quote
            b = readbyte(io)
        end
    end
    !eof(io) && readbyte(io) # ',' or '}'
    return takebuf_string(BUF)
end

function read{T}(::Type{Nullable{T}}, io::IOBuffer)
    b = peekbyte(io)
    if b == UInt8('n')
        @repeat 4 readbyte(io)
        !eof(io) && readbyte(io)
        return Nullable{T}()
    else
        return Nullable(read(T, io))
    end
end
function read(::Type{Void}, io::IOBuffer)
    @repeat 4 readbyte(io)
    !eof(io) && readbyte(io)
    return nothing
end

function read(::Type{Bool}, io::IOBuffer)
    b = readbyte(io)
    if b == UInt8('t')
        @repeat 3 readbyte(io)
        !eof(io) && readbyte(io)
        return true
    else
        @repeat 4 readbyte(io)
        !eof(io) && readbyte(io)
        return false
    end
end

end # module

using .JSON2
