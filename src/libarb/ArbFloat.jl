"""
from Arb docs:

A variable of type arf_t holds an arbitrary-precision binary floating-point number:
that is, a rational number of the form x⋅2y where x,y∈Z and x is odd, or one of
the special values zero, plus infinity, minus infinity, or NaN (not-a-number).
There is currently no support for negative zero, unsigned infinity, or a NaN with a payload.
""" ArbFloat

mutable struct ArbFloat{P} <: AbstractFloat    # P is the precision in bits
    exp::Int        # fmpz         exponent of 2 (2^exp)
    size::UInt      # mp_size_t    nwords and sign (lsb holds sign of significand)
    d1::UInt        # significand  unsigned, immediate value or the initial span
    d2::UInt        #   (d1, d2)   the final part indicating the significand, or 0

    function ArbFloat{P}() where {P}
        z = new{P}(0,0,0,0)
        ccall(@libarb(arf_init), Cvoid, (Ref{ArbFloat},), z)
        finalizer(arf_clear, z)
        return z
    end
end

# for use within structs, e.g ArbFloatMatrix
const PtrToArbFloat = Ptr{ArbFloat} # arf_ptr
const PtrToPtrToArbFloat = Ptr{Ptr{ArbFloat}} # arf_ptr*

arf_clear(x::ArbFloat{P}) where {P} = ccall(@libarb(arf_clear), Cvoid, (Ref{ArbFloat},), x)

ArbFloat{P}(x::ArbFloat{P}) where {P} = x
ArbFloat(x::ArbFloat{P}) where {P} = x

float(x::ArbFloat{P}) where {P} = x

ArbFloat{P}(x::Missing) where {P} = missing
ArbFloat(x::Missing) = missing

@inline sign_bit(x::ArbFloat{P}) where {P} = isodd(x.size)

# fallback constructor
ArbFloat{P}(x::T) where {P,T<:Real} = ArbFloat{P}(BigFloat(x))
ArbFloat(x::T) where {T<:Real} = ArbFloat{workingprecision(ArbFloat)}(BigFloat(x))
ArbFloat{P}(x::T) where {P,T<:Complex} = ArbFloat{P}(BigFloat(real(x)))
ArbFloat(x::T) where {T<:Complex} = ArbFloat{workingprecision(ArbFloat)}(BigFloat(real(x)))

ArbFloat(x, prec::Int) = prec>=MINIMUM_PRECISION ? ArbFloat{prec}(x) : throw(DomainError("bit precision $prec < $MINIMUM_PRECISION"))

function ArbFloat(x::T; bits::Int=0, digits::Int=0, base::Int=iszero(bits) ? 10 : 2) where {T<:Number}
    if base === 10
        digits = digits > 0 ? bits4digits(digits) : (bits > 0 ? bits : DEFAULT_PRECISION.x)
    elseif base === 2
        digits = bits > 0 ? bits : (digits > 0 ? digits : DEFAULT_PRECISION.x)
    else
        throw(ErrorException("base expects 2 or 10"))
    end
    ArbFloat(x, digits)
end

swap(x::ArbFloat{P}, y::ArbFloat{P}) where {P} = ccall(@libarb(arf_swap), Cvoid, (Ref{ArbFloat}, Ref{ArbFloat}), x, y)

function copy(x::ArbFloat{P}) where {P}
    z = ArbFloat{P}()
    ccall(@libarb(arf_set), Cvoid, (Ref{ArbFloat}, Ref{ArbFloat}), z, x)
    return z
end

function copy(x::ArbFloat{P}, bitprecision::Int, roundingmode::RoundingMode) where {P}
    z = ArbFloat{P}()
    rounding = match_rounding_mode(roundingmode)
    rounddir = ccall(@libarb(arf_set_round), Cint, (Ref{ArbFloat}, Ref{ArbFloat}, Clong, Cint), z, x, bitprecision, rounding)
    return z
end

copy(x::ArbFloat{P}, roundingmode::RoundingMode) where {P} = copy(x, P, roundingmode)
copy(x::ArbFloat{P}, bitprecision::Int) where {P} = copy(x, bitprecision, RoundNearest)


function ArbFloat{P}(x::Int32) where {P}
    z = ArbFloat{P}()
    ccall(@libarb(arf_set_si), Cvoid, (Ref{ArbFloat}, Clong), z, x)
    return z
end
ArbFloat{P}(x::T) where {P, T<:Union{Int8, Int16}} = ArbFloat{P}(Int32(x))
ArbFloat{P}(x::T) where {P, T<:Union{Int64, Int128}} = ArbFloat{P}(BigInt(x))

function ArbFloat{P}(x::UInt32) where {P}
    z = ArbFloat{P}()
    ccall(@libarb(arf_set_ui), Cvoid, (Ref{ArbFloat}, Culong), z, x)
    return z
end
ArbFloat{P}(x::T) where {P, T<:Union{UInt8, UInt16}} = ArbFloat{P}(UInt32(x))
ArbFloat{P}(x::T) where {P, T<:Union{UInt64, UInt128}} = ArbFloat{P}(BigInt(x))

function ArbFloat{P}(x::Float64) where {P}
    z = ArbFloat{P}()
    ccall(@libarb(arf_set_d), Cvoid, (Ref{ArbFloat}, Cdouble), z, x)
    return z
end
ArbFloat{P}(x::T) where {P, T<:Union{Float16, Float32}} = ArbFloat{P}(Float64(x))

function ArbFloat{P}(x::BigFloat) where {P}
    z = ArbFloat{P}()
    ccall(@libarb(arf_set_mpfr), Cvoid, (Ref{ArbFloat}, Ref{BigFloat}), z, x)
    return z
end
ArbFloat{P}(x::BigInt) where {P} = ArbFloat{P}(BigFloat(x))
ArbFloat{P}(x::Rational{T}) where {P, T<:Signed} = ArbFloat{P}(BigFloat(x))

function ArbFloat{P}(x::Irrational{S}) where {P,S}
    prec = precision(BigFloat)
    newprec = max(prec, P + 32)
    setprecision(BigFloat, newprec)
    y = BigFloat(x)
    z = ArbFloat{P}(y)
    setprecision(BigFloat, prec)
    return z
end

function Int64(x::ArbFloat{P}, roundingmode::RoundingMode) where {P}
    rounding = match_rounding_mode(roundingmode)
    z = ccall(@libarb(arf_get_si), Clong, (Ref{ArbFloat}, Cint), x, rounding)
    return z
end
Int32(x::ArbFloat{P}, roundingmode::RoundingMode) where {P} = Int32(Int64(x), roundingmode)
Int16(x::ArbFloat{P}, roundingmode::RoundingMode) where {P} = Int16(Int64(x), roundingmode)

BigFloat(x::ArbFloat{P}) where {P} = BigFloat(x, RoundNearest)
function BigFloat(x::ArbFloat{P}, roundingmode::RoundingMode) where {P}
    rounding = match_rounding_mode(roundingmode)
    z = BigFloat(0, workingprecision(x))
    roundingdir = ccall(@libarb(arf_get_mpfr), Cint, (Ref{BigFloat}, Ref{ArbFloat}, Cint), z, x, rounding)
    return z
end
BigFloat(x::ArbFloat{P}, bitprecision::Int) where {P} = BigFloat(x, bitprecision, RoundNearest)
function BigFloat(x::ArbFloat{P}, bitprecision::Int, roundingmode::RoundingMode) where {P}
    rounding = match_rounding_mode(roundingmode)
    z = BigFloat(0, bitprecision)
    roundingdir = ccall(@libarb(arf_get_mpfr), Cint, (Ref{BigFloat}, Ref{ArbFloat}, Cint), z, x, rounding)
    return z
end

BigInt(x::ArbFloat{P}) where {P} = BigInt(trunc(BigFloat(x)))

function Base.Integer(x::ArbFloat{P}) where {P}
    if isinteger(x)
       abs(x) <= typemax(Int64) ? Int64(x) : BigInt(x)
    else
       throw(InexactError("$x"))
    end
end

for (F,A) in ((:floor, :arf_floor), (:ceil, :arf_ceil))
    @eval begin
        function $F(x::ArbFloat{P}) where {P}
            z = ArbFloat{P}()
            ccall(@libarb($A), Cvoid, (Ref{ArbFloat}, Ref{ArbFloat}), z, x)
            return z
        end
        $F(::Type{T}, x::ArbFloat{P}) where {P, T<:Integer} = T($F(x))
    end
end

trunc(x::ArbFloat{P}) where {P} = signbit(x) ? ceil(x) : floor(x)
trunc(::Type{T}, x::ArbFloat{P}) where {P, T} = T(trunc(x))

midpoint(x::ArbFloat{P}) where {P} = x
radius(x::ArbFloat{P}) where {P} = zero(ArbFloat{P})


# a type specific hash function helps the type to 'just work'
const hash_arbfloat_lo = (UInt === UInt64) ? 0x37e642589da3416a : 0x5d46a6b4
const hash_0_arbfloat_lo = hash(zero(UInt), hash_arbfloat_lo)
hash(z::ArbFloat{P}, h::UInt) where {P} =
    hash(reinterpret(UInt,z.d1) ⊻ z.exp,
         (h ⊻ hash(z.d2 ⊻ (~reinterpret(UInt,P)), hash_arbfloat_lo) ⊻ hash_0_arbfloat_lo))
