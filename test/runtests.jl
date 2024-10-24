using SimultaneousSortperm
using Test
using Random
using OffsetArrays

Random.seed!(0xdeadbeef)

randnans(n) = reinterpret(Float64,[rand(UInt64)|0x7ff8000000000000 for i=1:n])

function randn_with_nans(n,p)
    v = randn(n)
    x = findall(rand(n).<p)
    v[x] = randnans(length(x))
    return v
end

@testset "SimultaneousSortperm.jl" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for T in [UInt16, Int, Float64], rev in [false, true], lt in [isless, >]
            for order in [Base.Order.Forward, Base.Order.Reverse], by in [identity, x->x÷100]

                skiptest = VERSION < v"1.9.0-rc1" && T != Int && by != identity && n > 20
                # Base.sort earlier than v"1.9.0-rc1" errors due to https://github.com/JuliaLang/julia/issues/48862
                # broken depending on rng -> infeasible to list all combinations

                v = rand(T,n)
                pref = sortperm(v, lt=lt, by=by, rev=rev, order=order)
                vref = sort(v, lt=lt, by=by, rev=rev, order=order)

                p = ssortperm(v, lt=lt, by=by, rev=rev, order=order)
                @test p == pref
                p == pref || println((T,rev,lt,order,by))

                p .= 0
                ssortperm!(p, v, lt=lt, by=by, rev=rev, order=order)
                @test p == pref
                v2 = copy(v)
                p = ssortperm!(v2, lt=lt, by=by, rev=rev, order=order)
                @test p == pref
                if VERSION >= v"1.7"
                    @test v2 == vref skip=skiptest
                elseif !skiptest
                    @test v2 == vref
                end

                v2 = copy(v)
                p .= 0
                ssortperm!!(p, v2, lt=lt, by=by, rev=rev, order=order)
                @test p == pref
                if VERSION >= v"1.7"
                    @test v2 == vref skip=skiptest
                elseif !skiptest
                    @test v2 == vref
                end

                if n>=1
                    for k in max.(Int.(ceil.(n .* [0.01, 0.1, 0.5, 0.9, 0.95])),1)
                        # println("partial")
                        # println("(T,rev,lt,order,by,(n,k)) = ", (T,rev,lt,order,by,(n,k)))
                        # display(v)
                        v0 = copy(v)
                        v2 = copy(v)
                        pref_k = sortperm(v, lt=lt, by=by, rev=rev, order=order)
                        vref_k = sort(v, lt=lt, by=by, rev=rev, order=order)
                        p = zeros(Int, n)

                        #=
                        v2 = copy(v)
                        p[1:k] .= spartialsortperm(v2, k, lt=lt, by=by, rev=rev, order=order)
                        @test by.(v0[p[1:k]]) == by.(v0[pref_k[1:k]])
                        # p[1:k] == pref_k[1:k] || println((T,rev,lt,order,by,(n,k)))
                        
                        v2 = copy(v)
                        p .= 0
                        spartialsortperm!(p, v2, k, lt=lt, by=by, rev=rev, order=order)
                        @test by.(v0[p[1:k]]) == by.(v0[pref_k[1:k]])
                        # p[1:k] == pref_k[1:k] || println((T,rev,lt,order,by,(n,k)))
                        if VERSION >= v"1.7"
                            @test by.(v2[1:k]) == by.(vref_k[1:k]) skip=skiptest
                        elseif !skiptest
                            @test by.(v2[1:k]) == by.(vref_k[1:k])
                        end
                        =#

                        v2 = copy(v)
                        p .= 0
                        spartialsortperm!!(p, v2, k, lt=lt, by=by, rev=rev, order=order)
                        @test by.(v0[p[1:k]]) == by.(v0[pref_k[1:k]])
                        if VERSION >= v"1.7"
                            @test by.(v2[1:k]) == by.(vref_k[1:k]) skip=skiptest
                        elseif !skiptest
                            @test by.(v2[1:k]) == by.(vref_k[1:k])
                        end
                        p[1:k] == pref_k[1:k] || println((T,rev,lt,order,by,(n,k)))
                        # v2[1:k] == vref_k[1:k] || println((T,rev,lt,order,by,(n,k)))
                    end
                end
            end
        end
    end
end;

@testset "OffsetArrays" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for offset in [-n , -1, 0, 1, n]
            v = OffsetArray(rand(Int,n), (1:n).+offset)
            pref = sortperm(v)
            vref = sort(v)

            p = ssortperm(v)
            @test p == pref

            v2 = copy(v)
            p .= 0
            ssortperm!!(p, v2)
            @test p == pref
            @test v2 == vref
        end
    end
end;

@testset "rand_with_NaNs and negative Floats" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        v = randn_with_nans(n,0.1)
        vo = OffsetArray(copy(v), (1:n).+100)
        for order in [Base.Order.Forward, Base.Order.Reverse]

            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            @test p == pref

            v2 = copy(v)
            p .= 0
            ssortperm!!(p, v2, order=order)
            @test p == pref
            @test reinterpret(UInt64,v2) == reinterpret(UInt64,vref)

            # offset
            prefo = sortperm(vo, order=order)
            vrefo = sort(vo, order=order)

            po = ssortperm(vo, order=order)
            @test po == prefo

            v2o = copy(vo)
            po .= 0
            ssortperm!!(po, v2o, order=order)
            @test po == prefo
            @test reinterpret(UInt64,v2o) == reinterpret(UInt64,vrefo)
        end
    end
end;

nan_and_not_missing(x) = !ismissing(x) ? isnan(x) : false
not_nan_and_not_missing(x) = !ismissing(x) ? !isnan(x) : false

@testset "missing" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        v = [rand(1:100) < 50 ? missing : randn_with_nans(1,0.1)[1] for _ in 1:n]
        vo = OffsetArray(copy(v), (1:n).+100)
        for order in [Base.Order.Forward, Base.Order.Reverse]
            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            @test p == pref

            v2 = copy(v)
            p .= 0
            ssortperm!!(p, v2, order=order)
            @test p == pref
            im_v2 = ismissing.(v2)
            im_vref = ismissing.(vref)
            @test im_v2 == im_vref
            if any(.!im_vref)
                # test NaNs and non NaNs seperately
                nonnan_vref = map(not_nan_and_not_missing, vref)
                nonnan_v2 = map(not_nan_and_not_missing, v2)
                if any(nonnan_vref)
                    @test reinterpret(UInt64,Float64.(v2[nonnan_v2])) == reinterpret(UInt64,Float64.(vref[nonnan_vref]))
                end
                # stability of NaNs is not guaranteed
                # and not satisfied in all versions of Base.sort
                # -> compare with input vector
                nan_v = map(nan_and_not_missing, v)
                nan_v2 = map(nan_and_not_missing, v2)
                if any(nan_v)
                    @test reinterpret(UInt64,Float64.(v2[nan_v2])) == reinterpret(UInt64,Float64.(v[nan_v]))
                end
            end

            # offset
            po = ssortperm(vo, order=order)
            @test issorted(vo[po], order=order)

            v2o = copy(vo)
            po .= 0
            ssortperm!!(po, v2o, order=order)
            @test issorted(vo[po], order=order)
            @test issorted(v2o, order=order)
        end
    end
end;

@testset "randstring" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for len in 0:17
            for order in [Base.Order.Forward, Base.Order.Reverse]
                v = [randstring(rand(0:len)) for _ in 1:n]
                vo  = OffsetArray(copy(v), (1:n).+100)

                pref = sortperm(v, order=order)
                vref = sort(v, order=order)

                p = ssortperm(v, order=order)
                @test p == pref

                v2 = copy(v)
                p .= 0
                ssortperm!!(p, v2, order=order)
                @test p == pref
                @test v2 == vref

                # offset
                prefo = sortperm(vo, order=order)
                vrefo = sort(vo, order=order)

                po = ssortperm(vo, order=order)
                @test po == prefo

                v2o = copy(vo)
                po .= 0
                ssortperm!!(po, v2o, order=order)
                @test po == prefo
                @test v2o == vrefo
            end
        end
    end
end;

@testset "bad_strings" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for len in [5,50,200]
            v = [String(rand(UInt8.([0,1,2,100,253,254,255]),rand(0:len))) for _ in 1:n]
            p = ssortperm(v)
            issorted(v[p]) || @show Base.CodeUnits.(v[p])
            @test issorted(v[p])
        end
    end
end;

@testset "short_strings_with_missing" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for len in 0:17
            for order in [Base.Order.Forward, Base.Order.Reverse]
                v = [rand(1:100) < 50 ? missing : String(rand(UInt8.([0,1,2,100,253,254,255]),rand(0:len))) for _ in 1:n]
                vo  = OffsetArray(copy(v), (1:n).+100)

                pref = sortperm(v, order=order)
                vref = sort(v, order=order)

                p = ssortperm(v, order=order)
                p == pref || println(v)
                @test p == pref

                v2 = copy(v)
                p .= 0
                ssortperm!!(p, v2, order=order)
                @test p == pref
                @test ismissing.(v2) == ismissing.(vref)
                @test issorted(v2, order=order)

                # offset
                po = ssortperm(vo, order=order)
                @test issorted(vo[po], order=order)

                v2o = copy(vo)
                po .= 0
                ssortperm!!(po, v2o, order=order)
                @test issorted(vo[po], order=order)
                @test issorted(v2o, order=order)
            end
        end
    end
end;

@testset "bool" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for order in [Base.Order.Forward, Base.Order.Reverse]
            v = rand(Bool,n)
            vo  = OffsetArray(copy(v), (1:n).+100)

            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            p == pref || println(v)
            @test p == pref
        end
    end
end;

@testset "bool_with_missing" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for order in [Base.Order.Forward, Base.Order.Reverse]
            v = [rand(1:100) < 33 ? missing : rand(Bool) for _ in 1:n]
            vo  = OffsetArray(copy(v), (1:n).+100)

            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            p == pref || println(v)
            @test p == pref
        end
    end
end;

@testset "small_int_range" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for order in [Base.Order.Forward, Base.Order.Reverse]
            v = rand(1:(n÷4+2),n)
            vo  = OffsetArray(copy(v), (1:n).+100)

            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            p == pref || println(v)
            @test p == pref
        end
    end
end;

@testset "small_int_range_with_missing" begin
    for n in [(0:33)..., 100, 999, 1000, 1001]
        for order in [Base.Order.Forward, Base.Order.Reverse]
            v = [rand(1:100) < 20 ? missing : rand(1:(n÷4+2)) for _ in 1:n]
            vo  = OffsetArray(copy(v), (1:n).+100)

            pref = sortperm(v, order=order)
            vref = sort(v, order=order)

            p = ssortperm(v, order=order)
            p == pref || println(v)
            @test p == pref
        end
    end
end;

if VERSION >= v"v1.9.0-alpha1"
    @testset "Matrix" begin
        for n in [(1:33)..., 100, 999, 1000, 1001]
            for m in [(1:33)..., 100, 999, 1000, 1001]
                A = rand(Int,n,m)
                Ao = OffsetArray(A, (1:n).+100, (1:m).+100)
                for order in [Base.Order.Forward, Base.Order.Reverse]
                    for dim in 1:2
                        pref = sortperm(A, order=order, dims=dim)
                        p = ssortperm(A, order=order, dims=dim)
                        @test p == pref

                        prefo = sortperm(Ao, order=order, dims=dim)
                        po = ssortperm(Ao, order=order, dims=dim)
                        @test po == prefo

                        p .= 0
                        ssortperm!(p, A, order=order, dims=dim)
                        @test p == pref

                        A2 = copy(A)
                        p = ssortperm!(A2, order=order, dims=dim)
                        @test p == pref
                        @test A2 == A[pref]

                        A2 .= A
                        p .= 0
                        ssortperm!!(p, order=order, A2, dims=dim)
                        @test p == pref
                        @test A2 == A[pref]
                    end
                end
            end
        end
    end;

    @testset "NDArray" begin
        for n in [1,31,32,33,34]
            for m in [1,31,32,33,34]
                for l in [1,31,32,33,34]
                    A = rand(Int, n, m, l)
                    for order in [Base.Order.Forward, Base.Order.Reverse]
                        for dim in 1:2:3

                            pref = sortperm(A, order=order, dims=dim)
                            p = ssortperm(A, order=order, dims=dim)
                            @test pref == p

                            A2 = copy(A)
                            p .= 0
                            ssortperm!!(p, A2, order=order, dims=dim)
                            @test pref == p
                            @test A2 == A[pref]
                        end
                    end
                end
            end
        end
    end;
else
    @testset "Matrix" begin
        for n in [(1:33)..., 100, 999, 1000, 1001]
            for m in [(1:33)..., 100, 999, 1000, 1001]
                A = rand(Int,n,m)
                for order in [Base.Order.Forward, Base.Order.Reverse]
                    p = ssortperm(A, order=order, dims=1)
                    As = A[p]
                    for i in 1:m
                        @test issorted(view(As,:,i), order=order)
                    end
                    p = ssortperm(A, order=order, dims=2)
                    As = A[p]
                    for i in 1:n
                        @test issorted(view(As,i,:), order=order)
                    end
                end
            end
        end
    end;
end