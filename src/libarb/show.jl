function show(io::IO, x::Mag)
    str = string(Float64(x))
    print(io, str)
end


function show(io::IO, x::ArbFloat{P}; midpoint::Bool=false) where {P}
    str = string(x, midpoint=midpoint)
    print(io, str)
end
showall(io::IO, x::ArbFloat{P}) where {P} = show(io, x, midpoint=true)

function show(io::IO, x::ArbReal{P}; midpoint::Bool=false, radius::Bool=false) where {P}
    str = string(x, midpoint=midpoint, radius=radius)
    print(io, str)
end
showall(io::IO, x::ArbReal{P}; radius::Bool=true) where {P} = show(io, x, midpoint=true, radius=radius)

function show(io::IO, x::ArbComplex{P}; midpoint::Bool=false, radius::Bool=false) where {P}
    str = string(x, midpoint=midpoint, radius=radius)
    print(io, str)
end
showall(io::IO, x::ArbComplex{P}; radius::Bool=true) where {P} = show(io, x, midpoint=true, radius=radius)


function show(x::ArbFloat{P}; midpoint::Bool=false) where {P}
    str = string(x, midpoint=midpoint)
    print(Base.stdout, str)
end
showall(x::ArbFloat{P}) where {P} = show(x, midpoint=true)

function show(x::ArbReal{P}; midpoint::Bool=false, radius::Bool=false) where {P}
    str = string(x, midpoint=midpoint, radius=radius)
    print(Base.stdout, str)
end
showall(x::ArbReal{P}; radius::Bool=true) where {P} = show(x, midpoint=true, radius=radius)

function show(x::ArbComplex{P}; midpoint::Bool=false, radius::Bool=false) where {P}
    str = string(x, midpoint=midpoint, radius=radius)
    print(Base.stdout, str)
end
showall(x::ArbComplex{P}; radius::Bool=true) where {P} = show(x, midpoint=true, radius=radius)

