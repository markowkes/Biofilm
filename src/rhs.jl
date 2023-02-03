
function biofilmRHS!(dsol,sol,p_r,t) 
    # Process param and range inputs
    p=p_r[1]
    r=p_r[2]

    # Unpack structs 
    @unpack Nx,Ns,Nz,rho,Kdet,mu = p

    # Split sol into dependent variables
    Xt,St,Pb,Sb,Lf=sol[r.Xt],sol[r.St],sol[r.Pb],sol[r.Sb],sol[r.Lf]
    Lf=Lf[1] # Convert length 1 vector into float
    Pb=reshape(Pb,Nx,Nz)
    Sb=reshape(Sb,Ns,Nz)

    # Compute particulate concentration from volume fractions
    Xb=similar(Pb)
    for j=1:Nx
        Xb[j,:] = rho[j]*Pb[j,:]
    end

    # Update grid
    z=range(0.0,Lf,Nz+1)
    zm=0.5*(z[1:Nz]+z[2:Nz+1])
    dz=z[2]-z[1]
    g=biofilmGrid(z,zm,dz)

    # Compute intermediate variables 
    fluxS = computeFluxS(St,Sb,p,g)           # Flux of substrate in biofilm
    μb    = computeMu_biofilm(Sb,Xb,Lf,t,p,g) # Growthrates in biofilm
    μt    = computeMu_tank(St,Xt,Lf,t,p,g)    # Growthrates in tank
    V     = computeVel(μb,Sb,Pb,t,p,g)        # Velocity of particulates
    Vdet  = Kdet*Lf^2                         # Detachment velocity
    fluxP = computeFluxP(Pb,V,p)              # Flux of particulates in biofilm

    # Compute RHS's
    dsol[r.Xt]=dXtdt(t,Xt,St,Xb,Lf,Vdet,μt,p,g) # Tank particulates
    dsol[r.St]=dStdt(t,Xt,St,Lf,Pb,fluxS,μt,p)  # Tank substrates
    dsol[r.Pb]=dPbdt(t,μb,Sb,Pb,fluxP,p,g)      # Biofilm particulates 
    dsol[r.Sb]=dSbdt(t,μb,Sb,Xb,fluxS,p,g)      # Biofilm substrates
    dsol[r.Lf]=dLfdt(V,Vdet)                    # Biofilm thickness
    return nothing
end

# RHS of tank particulates
function dXtdt(t,Xt,St,Xb,Lf,Vdet,μt,p,g)
    @unpack Nx,mu,Q,V,A,srcX = p
    dXt=similar(Xt)
    for j in 1:Nx
        dXt[j] = ( μt[j]*Xt[j]             # Growth
                - Q*Xt[j]/V               # Flow out
                + Vdet*A*Xb[j,end]/V     # From biofilm
                + srcX[j](St,Xt,t,p)[1] )  # Source term
    end
    return dXt
end

# RHS of tank substrates
function dStdt(t,Xt,St,Lf,Pb,fluxS,μt,p) 
    @unpack Ns,Q,Sin,srcS,V,A,Yxs = p
    dSt = zeros(Ns); 
    for k in 1:Ns                                 
        dSt[k] = ( Q.*Sin[k](t)/V              # Flow in
                - Q.*St[k]     /V              # Flow out
                - A.*fluxS[k,end]/V           # Flux into biofilm
                - sum(μt.*Xt./Yxs[:,k])        # Used by growth
                + srcS[k](St,Xt,t,p)[1] )       # Substrate source
        #if p.neutralization == true
        #    dS(k) = dS(k) - p.kB(k)*p.kdis(k)*p.rho(1)*Pb(1,end); # Neutralization
        #end
    end
    return dSt
end

# RHS of biofilm particulates 
function dPbdt(t,μb,Sb,Pb,fluxPb,p,g) 
    @unpack Nx,Nz,srcX,rho = p
    @unpack dz = g
    netFlux= (fluxPb[:,2:end]-fluxPb[:,1:end-1])/dz # Flux in/out
    growth = μb.*Pb                                 # Growth
    Source = zeros(Nx,Nz)
    for j in 1:Nx
        for i in 1:Nz
            Source[j,i] = srcX[j](Sb[:,i],Pb[:,i].*rho[:],t,p)[1]/rho[j]
        end
    end
    dPb  = growth - netFlux + Source;
    # Return RHS as a column vector
    dPb=reshape(dPb,Nx*Nz,1)
    return dPb
end

# RHS of biofilm substrates 
function dSbdt(t,μb,Sb,Xb,fluxS,p,g)
    @unpack Nx,Ns,Nz,srcS,rho,Yxs = p
    @unpack dz = g
    netFlux= (fluxS[:,2:end]-fluxS[:,1:end-1])/dz # Diffusion flux
    growth = zeros(Ns,Nz)
    for k in 1:Ns
        for j in 1:Nx
            growth[k,:] = growth[k,:] + μb[j,:].*Xb[j,:]./Yxs[j,k] # Used by growth
        end
    end
    Source = zeros(Ns,Nz)
    for k in 1:Ns
        for i in 1:Nz
            Source[k,i] = srcS[k](Sb[:,i],Xb[:,i],t,p)[1]
        end
    end
    dSb = netFlux - growth + Source
    # Return RHS as a column vector
    dSb=reshape(dSb,Ns*Nz,1)
    return dSb
end

# RHS of biofilm thickness
function dLfdt(V,Vdet)
    Vfilm = V[end]          # Growth velocity at top of biofilm
    dLf = Vfilm - Vdet    # Surface Velocity 
    return [dLf]
end