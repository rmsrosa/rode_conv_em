custom_solver = function(xt::Vector{T}, t0::T, tf::T, x0::T, f::F, yt::Vector{T}, rng::AbstractRNG) where {T, F}
    axes(xt) == axes(yt) || throw(
        DimensionMismatch("The vectors `xt` and `yt` must match indices")
    )

    n = size(xt, 1)
    dt = (tf - t0) / (n - 1)
    i1 = firstindex(xt)
    xt[i1] = x0
    integral = zero(T)
    for i in Iterators.drop(eachindex(xt, yt), 1)
        integral += (yt[i] + yt[i1]) * dt / 2 + sqrt(dt^3 / 12) * randn(rng)
        xt[i] = x0 * exp(integral)
        i1 = i
    end
end

@testset "Convergence" begin
    rng = Xoshiro(123)
    t0 = 0.0
    tf = 1.0
    ntgt = 2^12
    ns = 2 .^ (4:6)
    m = 500

    @testset "Scalar/Scalar Euler" begin

        x0law = Normal()
        y0 = 0.0
        noise = WienerProcess(t0, tf, y0)
        f = (t, x, y) -> y * x

        target = CustomUnivariateMethod(custom_solver, rng)
        method = RandomEuler()

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0

        target = RandomEuler()
        method = RandomEuler()

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0
    end

    @testset "Scalar/Vector Euler" begin

        x0law = Normal()
        y0 = 0.0
        noise = ProductProcess(
            WienerProcess(t0, tf, y0),
            WienerProcess(t0, tf, y0)
        )
        f = (t, x, y) -> (y[1] + 3y[2])/4 * x

        target_exact! = function (xt, t0, tf, x0, f, yt, rng)
            ntgt = size(xt, 1)
            dt = (tf - t0) / (ntgt - 1)
            xt[1] = x0
            integral = 0.0
            for n in 2:ntgt
                integral += (yt[n, 1] + yt[n-1, 1] + 3yt[n, 2] + 3yt[n-1, 2]) * dt / 8 + sqrt(dt^3 / 12) * randn(rng)
                xt[n] = x0 * exp(integral)
            end
        end

        target = CustomUnivariateMethod(target_exact!, rng)
        method = RandomEuler()

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0

        target = RandomEuler()
        method = RandomEuler()

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)
        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, RandomEuler(), RandomEuler(), ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0
    end

    @testset "Vector/scalar Euler" begin
        # two independent normals
        # but careful not to use `MvNormal(I(2))` because that uses a FillArray Zeros(2) for the means
        # which allocates due to trouble with broadcasting
        # see https://github.com/JuliaArrays/FillArrays.jl/issues/208
        x0law = MvNormal(zeros(2), I(2))
        # alternative implementation:
        # X0law = product_distribution(Normal(), Normal())
        y0 = 0.0
        noise = WienerProcess(t0, tf, y0)
        f! = (dx, t, x, y) -> (dx .= y .* x)

        target_exact! = function (xt, t0, tf, x0, f!, yt, rng)
            ntgt = size(xt, 1)
            dt = (tf - t0) / (ntgt - 1)
            xt[1, :] .= x0
            integral = 0.0
            for n in 2:ntgt
                integral += (yt[n] + yt[n-1]) * dt / 2 + sqrt(dt^3 / 12) * randn(rng)
                xt[n, :] .= exp(integral) * x0
            end
        end

        target = CustomMultivariateMethod(target_exact!, rng)
        method = RandomEuler(length(x0law))

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f!, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0

        target = RandomEuler(length(x0law))
        method = RandomEuler(length(x0law))

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f!, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0
    end

    @testset "Vector/Vector Euler" begin
        # two independent normals
        # two independent normals
        # but careful not to use `MvNormal(I(2))` because that uses a FillArray Zeros(2) for the means
        # which allocates dut to trouble with broadcasting
        # see https://github.com/JuliaArrays/FillArrays.jl/issues/208
        x0law = MvNormal(zeros(2), I(2))
        # alternative implementation:
        # X0law = product_distribution(Normal(), Normal())
        y0 = 0.0
        noise = ProductProcess(
            WienerProcess(t0, tf, y0),
            WienerProcess(t0, tf, y0)
        )
        f! = (dx, t, x, y) -> (dx .= (y[1] + 3y[2]) .* x ./ 4)

        target_exact! = function (xt, t0, tf, x0, f!, yt, rng)
            ntgt = size(xt, 1)
            dt = (tf - t0) / (ntgt - 1)
            xt[1, :] .= x0
            integral = 0.0
            for n in 2:ntgt
                integral += (yt[n, 1] + yt[n-1, 1] + 3yt[n, 2] + 3yt[n-1, 2]) * dt / 8 + sqrt(dt^3 / 12) * randn(rng)
                xt[n, :] .= exp(integral) * x0
            end
        end

        target = CustomMultivariateMethod(target_exact!, rng)
        method = RandomEuler(length(x0law))

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f!, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0

        target = RandomEuler(length(x0law))
        method = RandomEuler(length(x0law))

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f!, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
        # @test (@ballocated RODEConvergence.calculate_trajerrors!($rng, $trajerrors, $suite)) == 0
    end

    t0 = 0.0
    tf = 2.0
    ntgt = 2^16
    ns = 2 .^ (5:8)
    m = 500

    @testset "Scalar/Scalar Euler 2" begin
        x0law = Normal()
        y0 = 0.0
        noise = WienerProcess(t0, tf, y0)
        f = (t, x, y) -> y * x / 10

        target_exact! = function (xt, t0, tf, x0, f, yt, rng)
            ntgt = size(xt, 1)
            dt = (tf - t0) / (ntgt - 1)
            xt[1] = x0
            integral = 0.0
            for n in 2:ntgt
                integral += (yt[n] + yt[n-1]) * dt / 2 + sqrt(dt^3 / 12) * randn(rng)
                xt[n] = x0 * exp(integral / 10)
            end
        end

        target = CustomUnivariateMethod(target_exact!, rng)
        method = RandomEuler()

        suite = @test_nowarn ConvergenceSuite(t0, tf, x0law, f, noise, target, method, ntgt, ns, m)
        results = @test_nowarn solve(rng, suite)
        @test results.deltas ≈ (tf - t0) ./ (ns .- 1)
        @test results.p ≈ 1.0 (atol = 0.1)
    end
end
