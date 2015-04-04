#############
# Projector #
#############
type Projector{P,N} <: DiracOp{P,N}
    scalar::Number
    kt::Ket{P,N}
    br::Bra{P,N}
end

Projector{P,N}(::Type{P}, scalar, kt::Ket{P,N}, br::Bra{P,N}) = Projector{P,N}(scalar, kt, br)

Base.copy{P}(op::Projector{P}) = Projector(P, copy(op.scalar), copy(op.kt), copy(op.br))

Base.convert(::Type{GenericOp}, op::Projector) = scale!(op.scalar, GenericOp(op.kt, op.br))
Base.convert{P}(::Type{GenericOp{P}}, op::Projector{P}) = convert(GenericOp, op)
Base.convert{P,N}(::Type{GenericOp{P,N}}, op::Projector{P,N}) = convert(GenericOp, op)

Base.promote_rule(::Type{GenericOp}, ::Type{Projector}) = GenericOp
Base.promote_rule{P}(::Type{GenericOp{P}}, ::Type{Projector{P}}) = GenericOp{P}
Base.promote_rule{P,N}(::Type{GenericOp{P,N}}, ::Type{Projector{P,N}}) = GenericOp{P,N}

#######################
# Dict-Like Functions #
#######################
Base.(:(==)){P}(a::Projector{P}, b::Projector{P}) = a.scalar == b.scalar && a.kt == b.kt && a.br == b.br

Base.hash(op::Projector) = hash(op.scalar, hash(op.kt, hash(op.br)))
Base.length(op::Projector) = length(op.kt)*length(op.br)

Base.getindex(op::Projector, k::Array, b::Array) = op.scalar * op.kt[k] * op.br[b]
Base.getindex(op::Projector, label::OpLabel) = op[ktlabel(label), brlabel(label)]
Base.getindex(op::Projector, k, b) = op[[k],[b]]

# would be great if the below worked with normal indexing
# notation (e.g. op[k,:]) but slice notation is apparently
# special and doesn't dispatch directly to getindex...
# Base.getindex(op::Projector, k, ::Colon) = (op.scalar * op.kt[k]) * op.br
# Base.getindex(op::Projector, ::Colon, b) = (op.scalar * op.br[b]) * op.kt
# Base.getindex(op::Projector, ::Colon, ::Colon) = convert(GenericOp, op)

getbra(op::Projector, k::Array) = (op.scalar * op.kt[k]) * op.br
getket(op::Projector, b::Array) = (op.scalar * op.br[b]) * op.kt

Base.haskey(op::Projector, k::Array, b::Array) = hasket(op,k) && hasbra(op, b)
Base.haskey(op::Projector, label::OpLabel) = haskey(op, ktlabel(label), brlabel(label))
hasket(op::Projector, label::Array) = haskey(op.kt, label)
hasbra(op::Projector, label::Array) = haskey(op.br, label)

Base.get(op::Projector, label::OpLabel, default) = get(op, ktlabel(label), brlabel(label), default)
Base.get(op::Projector, k::Array, b::Array, default) = haskey(op, k, b) ? op[k,b] : default

label_from_pair(pair) = OpLabel(pair[1],pair[2])
labels(op::Projector) = imap(label_from_pair, product(labels(op.kt), labels(op.br)))
QuBase.coeffs(op::Projector) = imap(v->op.scalar*prod(v), product(coeffs(op.kt), coeffs(op.br)))

##################################################
# Function-passing functions (filter, map, etc.) #
##################################################
Base.filter(f::Function, op::Projector) = filter(f, convert(GenericOp, op))
Base.map(f::Function, op::Projector) = map(f, convert(GenericOp, op))

mapcoeffs(f::Function, op::Projector) = mapcoeffs(f, convert(GenericOp, op))
maplabels(f::Function, op::Projector) = maplabels(f, convert(GenericOp, op))

##############
# ctranspose #
##############
Base.ctranspose{P}(op::Projector{P}) = Projector(P, op.scalar', op.br', op.kt')

#########
# inner #
#########
inner(br::Bra, op::Projector) = op.scalar * inner(br, op.kt) * op.br
inner(op::Projector, kt::Ket) = op.scalar * op.kt * inner(op.br, kt)
inner(a::Projector, b::Projector) = Projector(a.scalar * b.scalar * inner(a.br,b.kt), a.kt, b.br)
inner(a::Projector, b::GeneralOp) = a.scalar * a.kt * inner(a.br, b)
inner(a::GeneralOp, b::Projector) = inner(a, b.kt) * b.br * b.scalar

##########
# act_on #
##########
act_on(op::Projector, kt::Ket, i) = act_on(convert(GenericOp, op), kt, i)

##########
# tensor #
##########
QuBase.tensor(kt::Ket, br::Bra) = Projector(1, kt, br)
QuBase.tensor(br::Bra, kt::Ket) = tensor(kt, br)
QuBase.tensor(a::Projector, b::Projector) = Projector(a.scalar * b.scalar, tensor(a.kt,b.kt), tensor(a.br, b.br))

###########
# Scaling #
###########
Base.scale!(c::Number, op::Projector) = (op.scalar = c*op.scalar; return op)
Base.scale!(op::Projector, c::Number) = (op.scalar = op.scalar*c; return op)

Base.scale(c::Number, op::Projector) = scale!(c,copy(op))
Base.scale(op::Projector, c::Number) = scale!(copy(op),c)

###########
# + and - #
###########
Base.(:-)(op::Projector) = scale(-1, op)
Base.(:+)(a::Projector, b::Projector) = convert(GenericOp, a) + convert(GenericOp, b)

#################
# Normalization #
#################
function Base.norm(op::Projector)
    result = 0
    for v in values(dict(op.kt)), c in values(dict(op.br))
        result += abs2(op.scalar * v * c')
    end
    return sqrt(result)
end

#########
# Trace #
#########
function Base.trace{O<:Orthonormal}(op::Projector{O})
    result = 0
    for k in labels(op.kt), b in labels(op.br)
        if b==k
            result += op[k,b]
        end
    end
    return result
end

function Base.trace{P}(op::Projector{P})
    result = 0
    for i in labels(op.kt), (k,v) in dict(op.kt), (b,c) in dict(op.br)
        result += v*c'*inner_rule(P, i, k) * inner_rule(P, b, i)
    end
    return op.scalar * result
end

#################
# Partial Trace #
#################
ptrace{P}(op::Projector{P,1}, over) = over == 1 ? trace(op) : throw(BoundsError())
ptrace(op::Projector, over) = ptrace_proj(op, over)

function ptrace_proj{O<:Orthonormal,N}(op::Projector{O,N}, over)
    result = OpDict()
    for k in labels(op.kt), b in labels(op.br)
        if k[over] == b[over]
            add_to_dict!(result,
                         OpLabel(except(k, over), except(b, over)),
                         op[k,b])
        end
    end
    return GenericOp(O,result,Factors{N-1}())
end

function ptrace_proj{P,N}(op::Projector{P,N}, over)
    result = OpDict()
    for i in labels(op.kt), (k,v) in dict(op.kt), (b,c) in dict(op.br)
        add_to_dict!(result,
                     OpLabel(except(k, over), except(b, over)),
                     op.scalar*v*c'*inner_rule(P, i[over], k[over])
                     *inner_rule(P, b[over], i[over]))
    end
    return GenericOp(P,result,Factors{N-1}())
end

########################
# Misc. Math Functions #
########################
nfactors{P,N}(op::Projector{P,N}) = N

xsubspace(op::Projector,x) = xsubspace(convert(GenericOp, op), x)
filternz(op::Projector) = filternz(convert(GenericOp, op))
purity(op::Projector) = trace(op^2)

######################
# Printing Functions #
######################
labelrepr(op::Projector, k, b, pad) = "$pad$(op[k,b]) $(ktstr(k))$(brstr(b))"

function Base.show(io::IO, op::Projector)
    print(io, summary(op)*":")
    pad = "  "
    maxlen = 4
    for k in take(keys(dict(op.kt)), maxlen),
        b in take(keys(dict(op.br)), maxlen)
        println(io)
        print(io, labelrepr(op, k, b, pad))
    end
    if length(op) > maxlen^2
        println(io)
        print(io, "$pad$vdots")
    end
end

export getbra,
    getket,
    hasket,
    hasbra,
    mapcoeffs,
    maplabels,
    ptrace,
    purity,
    labels,
    coeffs
