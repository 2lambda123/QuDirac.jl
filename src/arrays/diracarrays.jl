import Base: getindex,
    setindex!,
    copy,
    size,
    in,
    summary,
    +,
    sum

####################
# Helper Functions #
####################
    makecoeffarr(states::AbstractArray) = map(coeff, states)
    makecoeffarr(states...) = makecoeffarr(collect(states))

##############
# DiracArray #
##############
    # Dirac arrays are subtypes of AbstractQuArrays which generate
    # ScaledStates and ScaledOperators as elements. These 
    # quantum elements are formed by multiplying together 
    # the underlying QuArray's basis states with the associated
    # coefficients. 
    #
    # For example, the nth element of DiracVector{Ket, S} is 
    # the nth coefficient times a DiracState{Ket, S} whose label
    # is the nth label in the basis. 
    #
    # Likewise, the (ith, jth) element of DiracMatrix{Ket, S} is 
    # the (ith, jth) coefficient times a DiracOperator{S} whose 
    # ket label is the ith label in the row basis, and whose 
    # bra label is the jth label in the column basis.
    #
    # This kind of structure means we can do two cool things:
    # 
    # 1) If operations are being done within a single basis, we can 
    # bypass the performance cost of using states/basis and 
    # just operate on the coefficient arrays. If we're doing 
    # mixed basis operations, however, we can perform operations
    # utilizing the bras and kets themselves. 
    #
    # 2) Storing a basis of labels allows for label-based methods 
    # of analysis. An easy example is arbitrary selection/extraction 
    # of subspaces using methods like `filter`. (not yet implemented
    # here, but examples of which can be found in the old QuDirac repo).

    abstract DiracArray{B, T<:AbstractDirac, N} <: AbstractQuArray{B, T, N}

###############
# DiracVector #
###############
    checksize(::Type{Ket}, qa) = size(qa, 2) == 1 
    checksize(::Type{Bra}, qa) = size(qa, 1) == 1 

    type DiracVector{D, 
                     S<:AbstractStructure, 
                     T, 
                     B<:AbstractLabelBasis, 
                     N, 
                     A} <: DiracArray{(B,), ScaledState{D, S, T}, N}
        quarr::QuVector{B, T, N, A}
        function DiracVector{L<:AbstractLabelBasis{S}}(quarr::QuVector{L, T, N, A})
            if checksize(D, quarr)
                new(quarr)
            else 
                error("Coefficient array does not conform to input bases")
            end
        end
    end


    function DiracVector{L<:AbstractLabelBasis,T,N,A}(quarr::QuVector{L,T,N,A}, D::DataType=Ket)
        return DiracVector{D, structure(L), T, L, N, A}(quarr)
    end

    function DiracVector{T,S}(
                        coeffs::AbstractArray{T}, 
                        basis::AbstractLabelBasis{S}, 
                        D::DataType=Ket)
        return DiracVector(QuArray(coeffs, basis), D)    
    end

    DiracVector(coeffs::AbstractArray) = DiracVector(coeffs, FockBasis{AbstractStructure}(length(coeffs)-1))

    DiracVector{K<:AbstractKet}(arr::AbstractArray{K}) = sum(arr)
    DiracVector{B<:AbstractBra}(arr::AbstractArray{B}) = sum(arr)

    typealias KetVector{S<:AbstractStructure, T, B<:AbstractLabelBasis} DiracVector{Ket, S, T, B}
    typealias BraVector{S<:AbstractStructure, T, B<:AbstractLabelBasis} DiracVector{Bra, S, T, B}

    ######################
    # Property Functions #
    ######################
    size(dv::DiracVector, i...) = size(dv.quarr, i...)
    bases(dv::DiracVector) = bases(dv.quarr)
    basis(dv::DiracVector) = first(bases(dv))
    coeffs(dv::DiracVector) = coeffs(dv.quarr)
    dualtype{D}(::DiracVector{D}) = D
    structure{D,S<:AbstractStructure}(::DiracVector{D,S}) = S

    copy{D}(dv::DiracVector{D}) = DiracVector(copy(coeffs(dv)), copy(basis(dv)), D)
    ###################
    # Basis Functions #
    ###################
    in(s::AbstractState, dv::DiracVector) = in(label(s), basis(dv))
    getpos(dv::DiracVector, s) = getpos(basis(dv), s)
    getstate{D,S<:AbstractStructure}(dv::DiracVector{D,S}, i) = DiracState{D,S}(basis(dv)[i])
    samelabels(a::DiracVector, b::DiracVector) = samelabels(basis(a), basis(b))

    #########################
    # Coefficient Functions #
    #########################
    in(c, dv::DiracVector) = in(c, dv.quarr)
    getcoeff(dv::DiracVector, s::AbstractState) = coeffs(dv)[getpos(dv, s)]
    getcoeff(dv::DiracVector, s::StateLabel) = coeffs(dv)[getpos(dv, s)]
    getcoeff(dv::DiracVector, s::Tuple) = coeffs(dv)[getpos(dv, s)]
    getcoeff(dv::DiracVector, i) = coeffs(dv)[i]

    ######################
    # getindex/setindex! #
    ######################
    getindex(dv::DiracVector, arr::AbstractArray) = DiracVector([dv[i] for i in arr])
    getindex(dv::DiracVector, i::Real) = getcoeff(dv, i) * getstate(dv, i)
    getindex(dv::DiracVector, i) = getcoeff(dv, i) * getstate(dv, i)
    getindex(dv::DiracVector, s::AbstractState) = getcoeff(dv, s) * s
    getindex(dv::DiracVector, label::StateLabel) = getcoeff(dv, label) * s
    getindex(dv::DiracVector, label::Tuple) = getcoeff(dv, label) * s
    getindex(dv::KetVector, i, j) = j==1 ? dv[i] : throw(BoundsError())
    getindex(dv::BraVector, i, j) = i==1 ? dv[j] : throw(BoundsError())
    
    generic_setind!(dv, c, i) = (setindex!(coeffs(dv), c, i); return dv)
    setindex!(dv::DiracVector, c, s::AbstractState) = generic_setind!(dv, c, getpos(dv, s))
    setindex!(dv::DiracVector, c, i::Real) = generic_setind!(dv, c, i)
    setindex!(dv::DiracVector, c, i) = generic_setind!(dv, c, i)
    setindex!(v::KetVector, c, i, j) = j==1 ? generic_setind!(v, c, i) : throw(BoundsError())
    setindex!(v::BraVector, c, i, j) = i==1 ? generic_setind!(v, c, j) : throw(BoundsError())

    #####################
    # Joining Functions #
    #####################
    function addstate!(dv, state)
        dv[state] = getcoeff(dv, state) + coeff(state)
        return dv
    end

    function appendvec!(a, b)
        for i=1:length(b)
            a = a + b[i]
        end
        return a
    end

    function appendstate(dv::KetVector, state)
        return DiracVector(vcat(coeffs(dv), coeff(state)), append(basis(dv), label(state)), Ket)
    end

    function appendstate(dv::BraVector, state)
        return DiracVector(hcat(coeffs(dv), coeff(state)), append(basis(dv), label(state)), Bra)
    end

    ##########################
    # Mathematical Functions #
    ##########################

    function sum{K<:AbstractKet}(arr::AbstractArray{K})
        return DiracVector(makecoeffarr(arr), LabelBasis(arr), Ket)
    end

    function sum{B<:AbstractBra}(arr::AbstractArray{B})
        return DiracVector(makecoeffarr(arr), LabelBasis(arr), Bra)
    end

    function +{S}(a::AbstractKet{S}, b::AbstractKet{S}) 
        if a == b 
            return DiracVector([coeff(a) + coeff(b)], LabelBasis(b), Ket) 
        else 
            return DiracVector(vcat(coeff(a), coeff(b)), LabelBasis(a, b), Ket)
        end
    end

    function +{S}(a::AbstractBra{S}, b::AbstractBra{S}) 
        if a == b 
            return DiracVector([coeff(a) + coeff(b)], LabelBasis(b), Bra) 
        else 
            return DiracVector(hcat(coeff(a), coeff(b)), LabelBasis(a, b), Bra)
        end
    end

    function +{D,S<:AbstractStructure}(dv::DiracVector{D,S}, s::AbstractState{D,S})
        if s in dv
            return addstate!(copy(dv), s)
        else
            return appendstate(dv, s)
        end
    end

    +{D,S<:AbstractStructure}(s::AbstractState{D,S}, dv::DiracVector{D,S}) = +(dv, s)

    function +{D,S<:AbstractStructure}(a::DiracVector{D,S}, b::DiracVector{D,S})
        if samelabels(a, b)
            return DiracVector(coeffs(a) + coeffs(b), bases(a), D)
        else
            return appendvec!(copy(a), b)
        end
    end

    +(dv::DiracVector, arr::AbstractArray) = DiracVector(coeffs(dv)+arr, basis(dv), dualtype(dv))
    +(arr::AbstractArray, dv::DiracVector) = DiracVector(arr+coeffs(dv), basis(dv), dualtype(dv))

    ######################
    # Printing Functions #
    ######################
    summary{S<:AbstractStructure,T}(dv::KetVector{S,T}) = "KetVector{$S} with $(length(dv)) $T entries"
    summary{S<:AbstractStructure,T}(dv::BraVector{S,T}) = "BraVector{$S} with $(length(dv)) $T entries"

###############
# DiracMatrix #
###############
    type DiracMatrix{S<:AbstractStructure, 
                     T, 
                     R<:AbstractLabelBasis, 
                     C<:AbstractLabelBasis,
                     N,
                     A} <: DiracArray{(R,C), ScaledOperator{S, T}, N}
        quarr::QuMatrix{R, C, T, N, A}
        function DiracMatrix{R<:AbstractLabelBasis{S}, C<:AbstractLabelBasis{S}}(arr::QuMatrix{R, C, T, N, A})
            return new(quarr)
        end
    end

############################
# Convenience Constructors #
############################
    one_at_ind!(arr, i) = setindex!(arr, one(eltype(arr)), i)
    single_coeff(i, lens...) = one_at_ind!(zeros(Complex128, lens), i)
    diraccoeffs(i, len, ::Type{Ket}) = single_coeff(i, len)
    diraccoeffs(i, len, ::Type{Bra}) = single_coeff(i, 1, len)

    diracvec(i::Int, b::AbstractLabelBasis, D=Ket) = DiracVector(diraccoeffs(i, length(b), D), b, D)
    diracvec(tup::Tuple, b::AbstractLabelBasis, D=Ket) = DiracVector(diraccoeffs(getpos(b, tup), length(b), D), b, D)

    # `s` is the index at which 
    # the one coefficient resides;
    # if `s` is a tuple, it will be
    # treated like a label, and the
    # coefficient will be placed at
    # the label's position. If `s`
    # is a number, it will 
    # be treated like an index
    # into the coefficient
    # array
    ketvec(s, basis::FockBasis) = diracvec(s, basis, Ket)
    ketvec(s, lens::Tuple) = ketvec(s, FockBasis(lens))
    ketvec(s, lens...=s) = ketvec(s, lens)
    ketvec(s::Tuple) = ketvec(s, s)
    ketvec(s::Number) = ketvec(s, tuple(s-1))

    bravec(s, basis::FockBasis) = diracvec(s, basis, Bra)
    bravec(s, lens::Tuple) = bravec(s, FockBasis(lens))
    bravec(s, lens...=s) = bravec(s, lens)
    bravec(s::Tuple) = bravec(s, s)
    bravec(s::Number) = bravec(s, tuple(s-1))

export DiracArray,
    DiracVector,
    DiracMatrix,
    ketvec,
    bravec