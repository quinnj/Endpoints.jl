using Endpoints, Base.Test, HTTP

include("json2.jl")

Endpoints.@GET "test" ()->"testing GET resource"
Endpoints.@GET "test/{var::String}" var->"testing $var resource"
Endpoints.@GET "test/int/{var::Int}" var->"testing int $var resource"
Endpoints.@GET "test/type/{::Type{T}}" T->parse(T, "1")
Endpoints.@GET "test/sarv/ghotra" ()->"testing sarv ghotra conflict case"

type Bod
    id::Int
    nm::String
end

Endpoints.@POST "test/post" body body->"do you like my $body"
Endpoints.@POST "test/post/andarg/{arg}" body (arg, body)->"do you like my $arg and $body"
Endpoints.@POST "test/post/typedbod" body::Bod bod->"nice bod: $(bod.id), $(bod.nm)"

@async HTTP.serve(handler = Endpoints.handler)

# issue 4
res_body = String(take!(HTTP.get("http://localhost:8081/test/sarv")))
@test res_body == "\"testing sarv resource\""
