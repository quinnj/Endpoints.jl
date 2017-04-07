module Endpoints

include("json2.jl")

function parsequerystring(query::String)
    q = Dict{String,String}()
    length(query) == 0 && return q
    for field in split(query, "&")
        keyval = split(field, "=")
        length(keyval) != 2 && throw(ArgumentError("Field '$field' did not contain an '='."))
        q[unescape(keyval[1])] = unescape(keyval[2])
    end
    return q
end

# Resource Spec
  # provided as a String
  # path segments separated by "/"
  # normal URI-encoding rules apply (resource will not be encoded)
  # function positional arguments provided by "{name::type}", "{name}" or "{::Type{T}}"
    # "type" can be one of: Int, Float64, or String (default); (could potentially allow enums or Date/DateTime, bool?)
    # typed arguments will be converted to their type via `T(string_arg)`
    # if "{::Type{T}}", the path segment corresponds to an actualy Julia type `T`, which itself will be passed as an argument to the Julia function handler

# Body spec

# URI Query Parameters
 # query parameters contained in a URI such as "google.com/?search=julia"
 # will be passed to the julia function as keyword arguments
 # the julia function can explicitly define the keyword arguments it accepts (in which case, a URI that contains additional unsupported query parameters will not dispatch to this julia function)
 # the julia function can also include `f(x; kwargs...)`, which indicates a "varargs" catchall for extra keyword arguments
 # this ensures the julia function will be dispatched to, regardless of the query parameter or number of them
 # the HTTP standard doesn't restrict the use of duplicate query parameters in a URI, but julia functions can only contain unique keyword arguments,
 # duplicate keyword arguments can, however, be passed in a `kwargs...` varargs catch-all, providing a work-around
 # query parameters are always passed as String values, leaving the julia function itself to perform any conversions

macro GET(resource, func)
    generate_dispatch("GET", resource, nothing, func)
end

macro HEAD(resource, func)
    generate_dispatch("HEAD", resource, nothing, func)
end

macro POST(resource, body, func)
    generate_dispatch("POST", resource, body, func)
end

macro PUT(resource, body, func)
    generate_dispatch("PUT", resource, body, func)
end

macro DELETE(resource, func)
    generate_dispatch("DELETE", resource, nothing, func)
end

macro CONNECT(resource, func)
    generate_dispatch("CONNECT", resource, nothing, func)
end

macro OPTIONS(resource, func)
    generate_dispatch("OPTIONS", resource, nothing, func)
end

macro TRACE(resource, func)
    generate_dispatch("TRACE", resource, nothing, func)
end

macro PATCH(resource, body, func)
    generate_dispatch("PATCH", resource, body, func)
end


function generate_dispatch(method, resource, body, func)
    # split resource into Val & args
    args = []
    vals_and_args = []
    convert_args_block = quote end
    paths = split(resource, "/"; keep=false)
    for path in paths
        path == "" && continue
        if path[1] == '{' && path[end] == '}'
            # path argument
            arg = path[2:end-1]
            # if type not specified, it's a String by default
            !contains(arg, "::") && (arg *= "::String")
            if arg[1:2] == "::"
                !contains(arg, "::Type{") && throw(ArgumentError("malformed resource argument: $arg"))
                nm = Symbol(replace(string(gensym()), "#", "_"))
                arg = string(nm) * arg
                push!(convert_args_block.args, :($nm = eval(parse($nm))))
                push!(args, nm)
            else
                nm, typ = map(Symbol, split(arg, "::"))
                if typ != :String
                    push!(convert_args_block.args, :($nm = parse($typ, $nm)))
                end
                push!(args, nm)
            end
            string_arg = replace(arg, r"::.+", "::String")
            push!(vals_and_args, parse(string_arg))
        else
            # hard-coded path value
            pathsym = Symbol(path)
            push!(vals_and_args, :(::Type{Val{$(QuoteNode(pathsym))}}))
            Endpoints.PATH_LOOKUPS[path] = Val{pathsym}
        end
    end
    method_val = Type{Val{Symbol(method)}}
    if body != nothing
        spl = split(string(body), "::")
        nm = string(spl[1])
        push!(vals_and_args, parse(nm * "::String"))
        push!(args, Symbol(nm))
        typ = length(spl) > 1 ? Symbol(spl[2]) : :String
        push!(convert_args_block.args, :($(Symbol(nm)) = JSON2.read($(eval(current_module(), typ)), IOBuffer($(Symbol(nm))))))
    end
    return quote
        function $(esc(Symbol(Endpoints))).$(:__uri_dispatch__)(::$(method_val), $(vals_and_args...); query_params...)
            # convert args to expected types
            $(convert_args_block)
            $(esc(func))($(args...); query_params...)
        end
    end
end

function __uri_dispatch__ end

const PATH_LOOKUPS = Dict{String,DataType}()

# get, head, post, put, delete, trace, connect, patch, options
const METHOD_VALS = Dict{String, DataType}(
    "GET"     => Val{:GET},
    "HEAD"    => Val{:HEAD},
    "POST"    => Val{:POST},
    "PUT"     => Val{:PUT},
    "DELETE"  => Val{:DELETE},
    "TRACE"   => Val{:TRACE},
    "CONNECT" => Val{:CONNECT},
    "PATCH"   => Val{:PATCH},
    "OPTIONS" => Val{:OPTIONS}
)

function handler404(req, resp)
    resp.status = 404
    resp.data = req.resource.data
    return resp
end

# user can overload to
const BASE_PATH = "/"
function setbasepath!(x::String)
    global BASE_PATH = x
    return
end

const BUF = IOBuffer()

function handler(req, resp)
    vals_and_args = Any[get(PATH_LOOKUPS, seg, seg) for seg in splitpath(req.resource, length(BASE_PATH) + 1)]
    method_val = METHOD_VALS[req.method]
    query_params = parsequerystring(req.uri.query)
    if length(req.data) > 0
        push!(vals_and_args, String(req.data))
    end
    local ret
    try
        ret = Endpoints.__uri_dispatch__(method_val, vals_and_args...; query_params...)
    catch e
        if isa(e, MethodError)
            return handler404(req, resp)
        end
        println(e)
        rethrow(e)
    end
    JSON2.write(BUF, ret)
    resp.data = takebuf_array(BUF)
    return resp
end

#TODO
 # figure out a good way to do user authentication; add filterfunc(request)::Bool capabilities
 # handle 405 method not allowed for paths that match, but method doesn't
 # provide default OPTIONS response
 # find a small Domo service to re-write, see what's missing here
 # Database layer!!
   # see if Persist could be useful first (generic API that other "store" packages could implement)
     # can we get rich enough expression/semantics for parent-child_array operations?
   # do we focus on auto object mapping to tuples/records?
   # @transactional macro
   # function that takes julia args, then executes an SQL query w/ args properly sanitized?
   # be able to run migrations

end # module
