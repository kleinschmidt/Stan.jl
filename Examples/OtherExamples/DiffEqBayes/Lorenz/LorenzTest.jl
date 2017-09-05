using OrdinaryDiffEq, ParameterizedFunctions, RecursiveArrayTools
#using DiffEqBayes
using Stan, Mamba
using Base.Test

include(joinpath(Pkg.dir("Stan"), "Examples", "OtherExamples", "DiffEqBayes",
  "bayesian_inference.jl"))

#=
Experimental link to DiffEqBayes examples

Possible issues to investigate:

1. @ode_def_nohes needs to be kept outside local scope block
2. Minimize string replacements in Stan language model to prevent recompilations

=#

g1 = @ode_def_nohes LorenzExample begin
  dx = σ*(y-x)
  dy = x*(ρ-z) - y
  dz = x*y - β*z
end σ=10.0 ρ=28.0 β=>2.6666

ProjDir = dirname(@__FILE__)
cd(ProjDir) do

  #isdir("tmp") && rm("tmp", recursive=true)
  isfile("LorentzExample-summaryplot-1.pdf") &&
    rm("LorentzExample-summaryplot-1.pdf")
  isfile("LorentzExample-summaryplot-2.pdf") &&
    rm("LorentzExample-summaryplot-2.pdf")

  r0 = [0.1;0.0;0.0]
  tspan = (0.0,4.0)
  prob = ODEProblem(g1,r0,tspan)
  sol = solve(prob,Tsit5())
  t = collect(linspace(0.1,4.0,10))
  randomized = VectorOfArray([(sol(t[i]) + .01randn(3)) for i in 1:length(t)])
  data = convert(Array,randomized)
  priors = [Normal(2.6666,1)]

  bayesian_result = bayesian_inference(prob,t,data,priors;
    num_samples=1500,num_warmup=1500)
  theta1 = bayesian_result.chain_results[:,["theta.1"],:]
  global sim2 = bayesian_result.chain_results[1:end,
    ["sigma.1", "sigma.2", "sigma.3", "theta.1"], :]
  ## Plotting
  p = plot(sim2, [:trace, :mean, :density, :autocor], legend=true);
  draw(p, ncol=4, filename="Lorentz-summaryplot", fmt=:pdf)
  
  @test mean(theta1.value[:,:,1]) ≈ 2.6666 atol=1e-1

end
