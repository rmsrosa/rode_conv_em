module RODEConvergence

using Random
using Distributions
using LinearAlgebra
using FFTW
using Plots

import Random: rand

# noises
export AbstractProcess, UnivariateProcess, MultivariateProcess
export WienerProcess, GeometricBrownianMotionProcess
export CompoundPoissonProcess, PoissonStepProcess
export TransportProcess
export FractionalBrownianMotionProcess
export ProductProcess

# solvers
export RODEMethod, CustomUnivariateMethod, CustomMultivariateMethod, solve!
export RandomEuler, RandomHeun

# convergence calculation
export ConvergenceSuite, ConvergenceResult, solve

# output
export generate_error_table

include("noises.jl")
include("solvers.jl")
include("solver_euler.jl")
include("solver_heun.jl")
include("convergence.jl")
include("recipes.jl")

end # module RODEConvergence
