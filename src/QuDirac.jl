module QuDirac
    
    using Compat
    using Iterators.product

    if !(v"0.3-" <= VERSION < v"0.4-")
        warn("QuDirac v0.1 only officially supports the v0.3 release of Julia. Your version of Julia is $VERSION.")
    end
    
    ####################
    # String Constants #
    ####################
    const lang = "\u27E8"
    const rang = "\u27E9"
    const otimes = "\u2297"
    const vdots ="\u205E"

    ##################
    # Abstract Types #
    ##################
    abstract AbstractInner

    abstract AbstractDirac{P<:AbstractInner,N}
    abstract DiracOp{P,N} <: AbstractDirac{P,N}
    abstract DiracState{P,N} <: AbstractDirac{P,N}

    abstract DiracScalar <: Number

    #############
    # Functions #
    #############
    # tensor() will be in 
    # QuBase when it releases
    tensor() = error("Cannot call tensor function without arguments")
    tensor(s...) = reduce(tensor, s)

    prodtype{P}(::AbstractDirac{P}) = P

    predict_zero{T}(::Type{T}) = zero(T)
    predict_zero(::Type{Any}) = 0
    predict_one{T}(::Type{T}) = one(T)
    predict_one(::Type{Any}) = 1

    ######################
    # Include Statements #
    ######################
    include("labels.jl")
    include("inner.jl")
    include("state.jl")
    include("opsum.jl")
    include("outerproduct.jl")
    include("printfuncs.jl")
    include("dictfuncs.jl")
    include("mapfuncs.jl")
    include("str_macros.jl")
    include("funcop.jl")
    
    #################
    # default_inner #
    #################
    # Julia doesn't recompile functions within other 
    # previously compiled functions, so we can't have a 
    # get_default_inner() or something like that.
    #
    # Also, global optimization is poor, so we don't want
    # to use that either for most things. Thus, we go for
    # a function that straight-up redefines the default
    # constructors for the relevant objects. This is hacky,
    # but works for now, seeing as how only a few functions
    # actually "use" the default ptype.
    function default_inner{P<:AbstractInner}(::Type{P})
        QuDirac.ket(label::StateLabel) = ket(P, label)
        QuDirac.ket(items...) = ket(P, StateLabel(items))
        QuDirac.bra(items...) = Bra(ket(items...))
        info("QuDirac's default inner product type is currently $P.")
    end

    default_inner(KroneckerDelta);

    export AbstractInner,
        UndefinedInner,
        KroneckerDelta,
        default_inner,
        AbstractDirac,
        DiracState,
        DiracOp,
        # All functions that conflict 
        # with QuBase should be exported 
        # below:
        tensor,
        commute,
        anticommute,
        normalize,
        normalize!

end # module QuDirac
