using Test

const_int() = 1

let ci = @code_lowered const_int()
    @eval function yakc_trivial()
        $(Expr(:call, Core._yakc, Tuple{}, Any, Any, nothing, ci))
    end
end
@test yakc_trivial()() == 1

let ci = @code_lowered const_int()
    @eval function yakc_simple_inf()
        $(Expr(:call, Core._yakc, Tuple{}, Union{}, Any, nothing, ci))
    end
end
@test isa(yakc_simple_inf(), Core.YAKC{Tuple{}, Int})

struct YakcClos2Int
    a::Int
    b::Int
end
(a::YakcClos2Int)() = getfield(a, 1) + getfield(a, 2)
let ci = @code_lowered YakcClos2Int(1, 2)();
    @eval function yakc_trivial_clos()
        $(Expr(:call, Core._yakc, Tuple{}, Int64, Int64, (1, 2), ci))
    end
end
@test yakc_trivial_clos()() == 3

let ci = @code_lowered YakcClos2Int(1, 2)();
    @eval function yakc_self_call_clos()
        $(Expr(:call, Core._yakc, Tuple{}, Int64, Int64, (1, 2), ci))()
    end
end
@test yakc_self_call_clos() == 3
let opt = @code_typed yakc_self_call_clos()
    @test length(opt[1].code) == 1
    @test isa(opt[1].code[1], Core.ReturnNode)
end

struct YakcClos1Any
    a
end
(a::YakcClos1Any)() = getfield(a, 1)
let ci = @code_lowered YakcClos1Any(1)()
    @eval function yakc_pass_clos(x)
        $(Expr(:call, Core._yakc, Tuple{}, Any, Any, :((x,)), ci))
    end
end
@test yakc_pass_clos(1)() == 1
@test yakc_pass_clos("a")() == "a"

let ci = @code_lowered YakcClos1Any(1)()
    @eval function yakc_infer_pass_clos(x)
        $(Expr(:call, Core._yakc, Tuple{}, Union{}, Any, :((x,)), ci))
    end
end
@test isa(yakc_infer_pass_clos(1), Core.YAKC{Tuple{}, typeof(1)})
@test isa(yakc_infer_pass_clos("a"), Core.YAKC{Tuple{}, typeof("a")})
@test yakc_infer_pass_clos(1)() == 1
@test yakc_infer_pass_clos("a")() == "a"

let ci = @code_lowered identity(1)
    @eval function yakc_infer_pass_id()
        $(Expr(:call, Core._yakc, Tuple{Any}, Any, Any, nothing, ci))
    end
end
function complicated_identity(x)
    yakc_infer_pass_id()(x)
end
@test @inferred(complicated_identity(1)) == 1
@test @inferred(complicated_identity("a")) == "a"

struct YakcOpt
    A
end

(A::YakcOpt)() = ndims(getfield(A, 1))

let ci = @code_lowered YakcOpt([1 2])()
    @eval function yakc_opt_ndims(A)
        $(Expr(:call, Core._yakc, Tuple{}, Union{}, Any, :((A,)), ci))
    end
end
let A = [1 2]
    let yakc = yakc_opt_ndims(A)
        @test sizeof(yakc.env) == 0
        @test yakc() == 2
    end
end
