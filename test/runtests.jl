using Endpoints, Base.Test, HTTP

include("json2.jl")

Endpoints.@GET (@__MODULE__) "test" ()->"testing GET resource"
Endpoints.@GET @__MODULE__ "test/{var::String}" var->"testing $var resource"
Endpoints.@GET @__MODULE__ "test/int/{var::Int}" var->"testing int $var resource"
Endpoints.@GET @__MODULE__ "test/type/{::Type{T}}" T->parse(T, "1")
# Issue #2
path = "/test/dynamic/path"
Endpoints.@GET path ()->"testing path from variable"

type Bod
    id::Int
    nm::String
end

Endpoints.@POST "test/post" body body->"do you like my $body"
Endpoints.@POST "test/post/andarg/{arg}" body (arg, body)->"do you like my $arg and $body"
Endpoints.@POST "test/post/typedbod" body::Bod bod->"nice bod: $(bod.id), $(bod.nm)"

HTTP.serve(handler = Endpoints.handler)
