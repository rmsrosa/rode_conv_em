@testset "Test noises" begin
    t0 = 0.0
    tf = 2.0
    N = 2^8
    M = 5_000
    Ythf = Vector{Float64}(undef, M)
    Ytf = Vector{Float64}(undef, M)
    Yt = Vector{Float64}(undef, N)
    @testset "Wiener process" begin
        rng = Xoshiro(123)
        y0 = 0.0
        noise! = Wiener_noise(t0, tf, y0)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))

        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ 0.0 (atol = 0.05)
        @test var(Ythf) ≈ tf/2 (atol = 0.05)
        @test mean(Ytf) ≈ 0.0 (atol = 0.05)
        @test var(Ytf) ≈ tf (atol = 0.05)
    end

    @testset "gBm process" begin
        rng = Xoshiro(123)
        y0 = 0.4
        μ = 0.3
        σ = 0.2
        noise! = gBm_noise(t0, tf, μ, σ, y0)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))

        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ y0 * exp(μ * (tf / 2)) (atol = 0.05)
        @test var(Ythf) ≈ y0^2 * exp(2μ * (tf / 2)) * (exp(σ^2 * (tf / 2)) - 1) (atol = 0.05)
        @test mean(Ytf) ≈ y0 * exp(μ * tf) (atol = 0.1)
        @test var(Ytf) ≈ y0^2 * exp(2μ * tf) * (exp(σ^2 * tf) - 1) (atol = 0.05)
    end

    @testset "Compound Poisson" begin
        rng = Xoshiro(123)
        λ = 25.0
        μ = 0.5
        σ = 0.2
        dYlaw = Normal(μ, σ)
        noise! = CompoundPoisson_noise(t0, tf, λ, dYlaw)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))
        
        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ μ * λ * tf / 2 (atol = 0.1)
        @test var(Ythf) ≈ λ * (tf/2) * ( μ^2 + σ^2 ) (rtol = 0.1)
        @test mean(Ytf) ≈ μ * λ * tf (atol = 0.1)
        @test var(Ytf) ≈ λ * tf * ( μ^2 + σ^2 ) (rtol = 0.1)
    end

    @testset "Step Poisson" begin
        rng = Xoshiro(123)
        λ = 25.0
        α = 2.0
        β = 15.0
        Slaw = Beta(α, β)
        noise! = StepPoisson_noise(t0, tf, λ, Slaw)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))
        
        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ α/(α + β) (atol = 0.05)
        @test var(Ythf) ≈ α*β/(α + β)^2/(α + β + 1) (atol = 0.05)
        @test mean(Ytf) ≈ α/(α + β) (atol = 0.1)
        @test var(Ytf) ≈ α*β/(α + β)^2/(α + β + 1) (atol = 0.05)
    end

    @testset "Transport process" begin
        rng = Xoshiro(123)
        nr = 5
        f = (t, r) -> mapreduce(ri -> sin(ri*t), +, r)
        α = 2.0
        β = 15.0
        Ylaw = Beta(α, β)
        noise! = Transport_noise(t0, tf, f, Ylaw, nr)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))

        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ mean(sum(sin(r * tf / 2) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.02)
        @test var(Ythf) ≈ var(sum(sin(r * tf / 2) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.02)
        @test mean(Ytf) ≈ mean(sum(sin(r * tf) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.02)
        @test var(Ytf) ≈ var(sum(sin(r * tf) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.02)
    end

    @testset "fBm process" begin
        rng = Xoshiro(123)
        y0 = 0.0
        H = 0.25
        noise! = fBm_noise(t0, tf, y0, H, N)
        
        @test_nowarn noise!(rng, Yt)
        @test (@ballocated $noise!($rng, $Yt)) == 0
        @test_nowarn (@inferred noise!(rng, Yt))
        
        for m in 1:M
            noise!(rng, Yt)
            Ythf[m] = Yt[div(N, 2)]
            Ytf[m] = last(Yt)
        end
        @test mean(Ythf) ≈ 0.0 (atol = 0.05)
        @test var(Ythf) ≈ (tf/2)^(2H) (atol = 0.05)
        @test mean(Ytf) ≈ 0.0 (atol = 0.05)
        @test var(Ytf) ≈ tf^(2H) (atol = 0.05)
        rngcp = copy(rng)
        @test RODEConvergence.fG_daviesharte(rng, tf, N, H) ≈ RODEConvergence.fG_daviesharte_naive(rngcp, tf, N, H)
    end

    @testset "Multi noise" begin
        rng = Xoshiro(123)
        y0 = 0.0
        y0_gbm = 0.4
        μ = 0.3
        σ = 0.2
        λ = 25.0
        μ = 0.5
        dYlaw = Normal(μ, σ)
        λ = 25.0
        α = 2.0
        β = 15.0
        Slaw = Beta(α, β)
        nr = 5
        f = (t, r) -> mapreduce(ri -> sin(ri*t), +, r)
        Ylaw = Beta(α, β)
        H = 0.25
        noises = (
            Wiener_noise(t0, tf, y0),
            gBm_noise(t0, tf, μ, σ, y0_gbm),
            CompoundPoisson_noise(t0, tf, λ, dYlaw),
            StepPoisson_noise(t0, tf, λ, Slaw),
            Transport_noise(t0, tf, f, Ylaw, nr),
            fBm_noise(t0, tf, y0, H, N)
        )
        noise! = MultiProcess_noise(noises...)

        num_noises = length(noises)
        YMt = Matrix{Float64}(undef, N, num_noises)
        YMtf = Matrix{Float64}(undef, M, num_noises)

        @test_nowarn noise!(rng, YMt)

        # `MultiProcess_noise`` is allocating a little but it is not affecting performance and might just be due to closure behaving finicky sometimes
        # (per Jerry Ling (Moelf) https://github.com/Moelf on Slack)
        @test_broken (@ballocated $noise!($rng, $YMt)) == 0
        
        @test_nowarn (@inferred noise!(rng, YMt))

        for m in 1:M
            noise!(rng, YMt)
            for j in 1:num_noises
                YMtf[m, j] = YMt[end, j]
            end
        end
        means = mean(YMtf, dims=1)
        vars = var(YMtf, dims=1)
        
        @test means[1] ≈ 0.0 (atol = 0.1)
        @test vars[1] ≈ tf (atol = 0.1)

        @test means[2] ≈ y0_gbm * exp(μ * tf) (atol = 0.1)
        @test vars[2] ≈ y0_gbm^2 * exp(2μ * tf) * (exp(σ^2 * tf) - 1) (atol = 0.1)

        @test means[3] ≈ μ * λ * tf (atol = 0.1)
        @test vars[3] ≈ λ * tf * ( μ^2 + σ^2 ) (rtol = 0.1)

        @test means[4] ≈ α/(α + β) (atol = 0.1)
        @test vars[4] ≈ α*β/(α + β)^2/(α + β + 1) (atol = 0.1)

        @test means[5] ≈ mean(sum(sin(r * tf) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.05)
        @test vars[5] ≈ var(sum(sin(r * tf) for r in rand(rng, Ylaw, nr)) for _ in 1:M) (atol = 0.05)

        @test means[6] ≈ 0.0 (atol = 0.1)
        @test vars[6] ≈ tf^(2H) (atol = 0.1)
    end
end