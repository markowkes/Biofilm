# Convert solution (1D vec) into more meaningful dependent variables
# ## This method is optimized for plotting ##
# t,X,S,Lf = f(t), Pb,Sb = f(z)
function unpack_solutionForPlot(sol,p,r)
    @unpack Nx,Ns,Nz=p
    t=sol.t
    Xt=sol[r.Xt,:]
    St=sol[r.St,:]
    Pb=sol[r.Pb,end]
    Sb=sol[r.Sb,end]
    Lf=sol[r.Lf,:]

    # Reshape biofilm variables
    Pb=reshape(Pb,Nx,Nz)
    Sb=reshape(Sb,Ns,Nz)
    
    return t,Xt,St,Pb,Sb,Lf
end

# Return greatest common divisor of floats
function Base.gcd(a::Float64,b::Float64)

    # Check order of numbers
    a < b && return gcd(b, a)

    # Check for Inf 
    a ≈ Inf && return b
    
    # base case
    if abs(b) < eps(Float64)
        return a
    else
        return (gcd(b, a - floor(a / b) * b))
    
    end
end


function printBiofilmTitles(p)
    @unpack XNames,SNames = p
    # Build output string
    str=@sprintf(" %8s |"," Time  ")
    map( (x) -> str*=@sprintf(" %8.8s |",x),XNames)
    map( (x) -> str*=@sprintf(" %8.8s |",x),SNames)
    map( (x) -> str*=@sprintf(" min,max(%8.8s) |",x),XNames)
    map( (x) -> str*=@sprintf(" min,max(%8.8s) |",x),SNames)
    str*=@sprintf(" %8s"," Lf [μm] ")
    # Print string
    println(str)
    return
end

function printBiofilmValues(t,Xt,St,Pb,Sb,Lf,p)
    @unpack Nx,Ns = p
    # Build output string
    str=@sprintf(" %8.3f |",t)
    map( (x)   -> str*=@sprintf(" %8.3g |",x),Xt)
    map( (x)   -> str*=@sprintf(" %8.3g |",x),St)
    for i in 1:Nx
        map( (x,y) -> str*=@sprintf(" %8.3g,%8.3g |",x,y),minimum(Pb[i,:]),maximum(Pb[i,:]))
    end
    for i in 1:Ns
        map( (x,y) -> str*=@sprintf(" %8.3g,%8.3g |",x,y),minimum(Sb[i,:]),maximum(Sb[i,:]))
    end
    map( (x)   -> str*=@sprintf(" %8.3g",x),1e6*Lf)
    # Print string
    println(str)
    return
end


