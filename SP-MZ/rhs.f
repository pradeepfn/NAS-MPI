c---------------------------------------------------------------------
c---------------------------------------------------------------------

       subroutine compute_rhs(rho_i, us, vs, ws, speed, qs, square,
     $                        rhs, forcing, u, nx, nxmax, ny, nz)

c---------------------------------------------------------------------
c---------------------------------------------------------------------

       include 'header.h'

       integer nx, nxmax, ny, nz
       double precision rho_i  (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  us     (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  vs     (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  ws     (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  speed  (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  qs     (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  square (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  rhs    (5,0:nxmax-1,0:ny-1,0:nz-1), 
     $                  forcing(5,0:nxmax-1,0:ny-1,0:nz-1), 
     $                  u      (5,0:nxmax-1,0:ny-1,0:nz-1)

       integer i, j, k, m
       double precision aux, rho_inv, uijk, up1, um1, vijk, vp1, vm1,
     >                  wijk, wp1, wm1


!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(m,aux,rho_inv,i,j,k)
!$OMP&  SHARED(c1c2,nx,ny,nz)
c---------------------------------------------------------------------
c      compute the reciprocal of density, and the kinetic energy, 
c      and the speed of sound. 
c---------------------------------------------------------------------

!$OMP DO
       do    k = 0, nz-1
          do    j = 0, ny-1
             do    i = 0, nx-1
                rho_inv = 1.0d0/u(1,i,j,k)
                rho_i(i,j,k) = rho_inv
                us(i,j,k) = u(2,i,j,k) * rho_inv
                vs(i,j,k) = u(3,i,j,k) * rho_inv
                ws(i,j,k) = u(4,i,j,k) * rho_inv
                square(i,j,k)     = 0.5d0* (
     >                        u(2,i,j,k)*u(2,i,j,k) + 
     >                        u(3,i,j,k)*u(3,i,j,k) +
     >                        u(4,i,j,k)*u(4,i,j,k) ) * rho_inv
                qs(i,j,k) = square(i,j,k) * rho_inv
c---------------------------------------------------------------------
c               (don't need speed and ainx until the lhs computation)
c---------------------------------------------------------------------
                aux = c1c2*rho_inv* (u(5,i,j,k) - square(i,j,k))
                speed(i,j,k) = dsqrt(aux)
             end do
          end do
       end do
!$OMP END DO nowait

c---------------------------------------------------------------------
c copy the exact forcing term to the right hand side;  because 
c this forcing term is known, we can store it on the whole zone
c including the boundary                   
c---------------------------------------------------------------------

!$OMP DO
       do    k = 0, nz-1
          do    j = 0, ny-1
             do    i = 0, nx-1
                do    m = 1, 5
                   rhs(m,i,j,k) = forcing(m,i,j,k)
                end do
             end do
          end do
       end do
!$OMP END DO nowait
!$OMP END PARALLEL

c---------------------------------------------------------------------
c      compute xi-direction fluxes 
c---------------------------------------------------------------------
       if (timeron) call timer_start(t_rhsx)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(m,um1,up1,uijk,i,j,k)
!$OMP&  SHARED(dssp,c1,xxcon5,xxcon4,xxcon3,dx5tx1,dx4tx1,dx3tx1,c2,
!$OMP& con43,xxcon2,dx2tx1,tx2,dx1tx1,nx,ny,nz)
       do    k = 1, nz-2
          do    j = 1, ny-2
             do    i = 1, nx-2
                uijk = us(i,j,k)
                up1  = us(i+1,j,k)
                um1  = us(i-1,j,k)

                rhs(1,i,j,k) = rhs(1,i,j,k) + dx1tx1 * 
     >                    (u(1,i+1,j,k) - 2.0d0*u(1,i,j,k) + 
     >                     u(1,i-1,j,k)) -
     >                    tx2 * (u(2,i+1,j,k) - u(2,i-1,j,k))

                rhs(2,i,j,k) = rhs(2,i,j,k) + dx2tx1 * 
     >                    (u(2,i+1,j,k) - 2.0d0*u(2,i,j,k) + 
     >                     u(2,i-1,j,k)) +
     >                    xxcon2*con43 * (up1 - 2.0d0*uijk + um1) -
     >                    tx2 * (u(2,i+1,j,k)*up1 - 
     >                           u(2,i-1,j,k)*um1 +
     >                           (u(5,i+1,j,k)- square(i+1,j,k)-
     >                            u(5,i-1,j,k)+ square(i-1,j,k))*
     >                            c2)

                rhs(3,i,j,k) = rhs(3,i,j,k) + dx3tx1 * 
     >                    (u(3,i+1,j,k) - 2.0d0*u(3,i,j,k) +
     >                     u(3,i-1,j,k)) +
     >                    xxcon2 * (vs(i+1,j,k) - 2.0d0*vs(i,j,k) +
     >                              vs(i-1,j,k)) -
     >                    tx2 * (u(3,i+1,j,k)*up1 - 
     >                           u(3,i-1,j,k)*um1)

                rhs(4,i,j,k) = rhs(4,i,j,k) + dx4tx1 * 
     >                    (u(4,i+1,j,k) - 2.0d0*u(4,i,j,k) +
     >                     u(4,i-1,j,k)) +
     >                    xxcon2 * (ws(i+1,j,k) - 2.0d0*ws(i,j,k) +
     >                              ws(i-1,j,k)) -
     >                    tx2 * (u(4,i+1,j,k)*up1 - 
     >                           u(4,i-1,j,k)*um1)

                rhs(5,i,j,k) = rhs(5,i,j,k) + dx5tx1 * 
     >                    (u(5,i+1,j,k) - 2.0d0*u(5,i,j,k) +
     >                     u(5,i-1,j,k)) +
     >                    xxcon3 * (qs(i+1,j,k) - 2.0d0*qs(i,j,k) +
     >                              qs(i-1,j,k)) +
     >                    xxcon4 * (up1*up1 -       2.0d0*uijk*uijk + 
     >                              um1*um1) +
     >                    xxcon5 * (u(5,i+1,j,k)*rho_i(i+1,j,k) - 
     >                              2.0d0*u(5,i,j,k)*rho_i(i,j,k) +
     >                              u(5,i-1,j,k)*rho_i(i-1,j,k)) -
     >                    tx2 * ( (c1*u(5,i+1,j,k) - 
     >                             c2*square(i+1,j,k))*up1 -
     >                            (c1*u(5,i-1,j,k) - 
     >                             c2*square(i-1,j,k))*um1 )
             end do

c---------------------------------------------------------------------
c      add fourth order xi-direction dissipation               
c---------------------------------------------------------------------

             i = 1
             do    m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k)- dssp * 
     >                    ( 5.0d0*u(m,i,j,k) - 4.0d0*u(m,i+1,j,k) +
     >                            u(m,i+2,j,k))
             end do

             i = 2
             do    m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (-4.0d0*u(m,i-1,j,k) + 6.0d0*u(m,i,j,k) -
     >                      4.0d0*u(m,i+1,j,k) + u(m,i+2,j,k))
             end do

             do  i = 3, nx-4
                do     m = 1, 5
                   rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (  u(m,i-2,j,k) - 4.0d0*u(m,i-1,j,k) + 
     >                     6.0*u(m,i,j,k) - 4.0d0*u(m,i+1,j,k) + 
     >                         u(m,i+2,j,k) )
                end do
             end do

             i = nx-3
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i-2,j,k) - 4.0d0*u(m,i-1,j,k) + 
     >                      6.0d0*u(m,i,j,k) - 4.0d0*u(m,i+1,j,k) )
             end do

             i = nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i-2,j,k) - 4.d0*u(m,i-1,j,k) +
     >                      5.d0*u(m,i,j,k) )
             end do
          end do
       end do
!$OMP END PARALLEL DO
       if (timeron) call timer_stop(t_rhsx)

c---------------------------------------------------------------------
c      compute eta-direction fluxes 
c---------------------------------------------------------------------
       if (timeron) call timer_start(t_rhsy)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(m,vm1,vp1,vijk,i,j,k)
!$OMP&  SHARED(dssp,c1,yycon5,yycon4,yycon3,dy5ty1,dy4ty1,c2,con43,
!$OMP& dy3ty1,yycon2,dy2ty1,ty2,dy1ty1,nx,ny,nz)
       do     k = 1, nz-2
          do     j = 1, ny-2
             do     i = 1, nx-2
                vijk = vs(i,j,k)
                vp1  = vs(i,j+1,k)
                vm1  = vs(i,j-1,k)
                rhs(1,i,j,k) = rhs(1,i,j,k) + dy1ty1 * 
     >                   (u(1,i,j+1,k) - 2.0d0*u(1,i,j,k) + 
     >                    u(1,i,j-1,k)) -
     >                   ty2 * (u(3,i,j+1,k) - u(3,i,j-1,k))
                rhs(2,i,j,k) = rhs(2,i,j,k) + dy2ty1 * 
     >                   (u(2,i,j+1,k) - 2.0d0*u(2,i,j,k) + 
     >                    u(2,i,j-1,k)) +
     >                   yycon2 * (us(i,j+1,k) - 2.0d0*us(i,j,k) + 
     >                             us(i,j-1,k)) -
     >                   ty2 * (u(2,i,j+1,k)*vp1 - 
     >                          u(2,i,j-1,k)*vm1)
                rhs(3,i,j,k) = rhs(3,i,j,k) + dy3ty1 * 
     >                   (u(3,i,j+1,k) - 2.0d0*u(3,i,j,k) + 
     >                    u(3,i,j-1,k)) +
     >                   yycon2*con43 * (vp1 - 2.0d0*vijk + vm1) -
     >                   ty2 * (u(3,i,j+1,k)*vp1 - 
     >                          u(3,i,j-1,k)*vm1 +
     >                          (u(5,i,j+1,k) - square(i,j+1,k) - 
     >                           u(5,i,j-1,k) + square(i,j-1,k))
     >                          *c2)
                rhs(4,i,j,k) = rhs(4,i,j,k) + dy4ty1 * 
     >                   (u(4,i,j+1,k) - 2.0d0*u(4,i,j,k) + 
     >                    u(4,i,j-1,k)) +
     >                   yycon2 * (ws(i,j+1,k) - 2.0d0*ws(i,j,k) + 
     >                             ws(i,j-1,k)) -
     >                   ty2 * (u(4,i,j+1,k)*vp1 - 
     >                          u(4,i,j-1,k)*vm1)
                rhs(5,i,j,k) = rhs(5,i,j,k) + dy5ty1 * 
     >                   (u(5,i,j+1,k) - 2.0d0*u(5,i,j,k) + 
     >                    u(5,i,j-1,k)) +
     >                   yycon3 * (qs(i,j+1,k) - 2.0d0*qs(i,j,k) + 
     >                             qs(i,j-1,k)) +
     >                   yycon4 * (vp1*vp1       - 2.0d0*vijk*vijk + 
     >                             vm1*vm1) +
     >                   yycon5 * (u(5,i,j+1,k)*rho_i(i,j+1,k) - 
     >                             2.0d0*u(5,i,j,k)*rho_i(i,j,k) +
     >                             u(5,i,j-1,k)*rho_i(i,j-1,k)) -
     >                   ty2 * ((c1*u(5,i,j+1,k) - 
     >                           c2*square(i,j+1,k)) * vp1 -
     >                          (c1*u(5,i,j-1,k) - 
     >                           c2*square(i,j-1,k)) * vm1)
             end do
          end do

c---------------------------------------------------------------------
c      add fourth order eta-direction dissipation         
c---------------------------------------------------------------------

          j = 1
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k)- dssp * 
     >                    ( 5.0d0*u(m,i,j,k) - 4.0d0*u(m,i,j+1,k) +
     >                            u(m,i,j+2,k))
             end do
          end do

          j = 2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (-4.0d0*u(m,i,j-1,k) + 6.0d0*u(m,i,j,k) -
     >                      4.0d0*u(m,i,j+1,k) + u(m,i,j+2,k))
             end do
          end do

          do    j = 3, ny-4
             do  i = 1,nx-2
                do     m = 1, 5
                   rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (  u(m,i,j-2,k) - 4.0d0*u(m,i,j-1,k) + 
     >                     6.0*u(m,i,j,k) - 4.0d0*u(m,i,j+1,k) + 
     >                         u(m,i,j+2,k) )
                end do
             end do
          end do
 
          j = ny-3
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i,j-2,k) - 4.0d0*u(m,i,j-1,k) + 
     >                      6.0d0*u(m,i,j,k) - 4.0d0*u(m,i,j+1,k) )
             end do
          end do

          j = ny-2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i,j-2,k) - 4.d0*u(m,i,j-1,k) +
     >                      5.d0*u(m,i,j,k) )
             end do
          end do
       end do
!$OMP END PARALLEL DO
       if (timeron) call timer_stop(t_rhsy)

c---------------------------------------------------------------------
c      compute zeta-direction fluxes 
c---------------------------------------------------------------------
       if (timeron) call timer_start(t_rhsz)
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(m,wm1,wp1,wijk,i,j,k)
!$OMP&  SHARED(dssp,c1,zzcon5,zzcon4,zzcon3,dz5tz1,c2,con43,dz4tz1,
!$OMP& dz3tz1,zzcon2,dz2tz1,tz2,dz1tz1,nx,ny,nz)
!$OMP DO
       do    k = 1, nz-2
          do     j = 1, ny-2
             do     i = 1, nx-2
                wijk = ws(i,j,k)
                wp1  = ws(i,j,k+1)
                wm1  = ws(i,j,k-1)

                rhs(1,i,j,k) = rhs(1,i,j,k) + dz1tz1 * 
     >                   (u(1,i,j,k+1) - 2.0d0*u(1,i,j,k) + 
     >                    u(1,i,j,k-1)) -
     >                   tz2 * (u(4,i,j,k+1) - u(4,i,j,k-1))
                rhs(2,i,j,k) = rhs(2,i,j,k) + dz2tz1 * 
     >                   (u(2,i,j,k+1) - 2.0d0*u(2,i,j,k) + 
     >                    u(2,i,j,k-1)) +
     >                   zzcon2 * (us(i,j,k+1) - 2.0d0*us(i,j,k) + 
     >                             us(i,j,k-1)) -
     >                   tz2 * (u(2,i,j,k+1)*wp1 - 
     >                          u(2,i,j,k-1)*wm1)
                rhs(3,i,j,k) = rhs(3,i,j,k) + dz3tz1 * 
     >                   (u(3,i,j,k+1) - 2.0d0*u(3,i,j,k) + 
     >                    u(3,i,j,k-1)) +
     >                   zzcon2 * (vs(i,j,k+1) - 2.0d0*vs(i,j,k) + 
     >                             vs(i,j,k-1)) -
     >                   tz2 * (u(3,i,j,k+1)*wp1 - 
     >                          u(3,i,j,k-1)*wm1)
                rhs(4,i,j,k) = rhs(4,i,j,k) + dz4tz1 * 
     >                   (u(4,i,j,k+1) - 2.0d0*u(4,i,j,k) + 
     >                    u(4,i,j,k-1)) +
     >                   zzcon2*con43 * (wp1 - 2.0d0*wijk + wm1) -
     >                   tz2 * (u(4,i,j,k+1)*wp1 - 
     >                          u(4,i,j,k-1)*wm1 +
     >                          (u(5,i,j,k+1) - square(i,j,k+1) - 
     >                           u(5,i,j,k-1) + square(i,j,k-1))
     >                          *c2)
                rhs(5,i,j,k) = rhs(5,i,j,k) + dz5tz1 * 
     >                   (u(5,i,j,k+1) - 2.0d0*u(5,i,j,k) + 
     >                    u(5,i,j,k-1)) +
     >                   zzcon3 * (qs(i,j,k+1) - 2.0d0*qs(i,j,k) + 
     >                             qs(i,j,k-1)) +
     >                   zzcon4 * (wp1*wp1 - 2.0d0*wijk*wijk + 
     >                             wm1*wm1) +
     >                   zzcon5 * (u(5,i,j,k+1)*rho_i(i,j,k+1) - 
     >                             2.0d0*u(5,i,j,k)*rho_i(i,j,k) +
     >                             u(5,i,j,k-1)*rho_i(i,j,k-1)) -
     >                   tz2 * ( (c1*u(5,i,j,k+1) - 
     >                            c2*square(i,j,k+1))*wp1 -
     >                           (c1*u(5,i,j,k-1) - 
     >                            c2*square(i,j,k-1))*wm1)
             end do
          end do
       end do
!$OMP END DO

c---------------------------------------------------------------------
c      add fourth order zeta-direction dissipation                
c---------------------------------------------------------------------

       k = 1
!$OMP DO
       do     j = 1, ny-2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k)- dssp * 
     >                    ( 5.0d0*u(m,i,j,k) - 4.0d0*u(m,i,j,k+1) +
     >                            u(m,i,j,k+2))
             end do
          end do
       end do
!$OMP END DO nowait

       k = 2
!$OMP DO
       do     j = 1, ny-2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (-4.0d0*u(m,i,j,k-1) + 6.0d0*u(m,i,j,k) -
     >                      4.0d0*u(m,i,j,k+1) + u(m,i,j,k+2))
             end do
          end do
       end do
!$OMP END DO nowait

       do     k = 3, nz-4
!$OMP DO
          do     j = 1, ny-2
             do     i = 1,nx-2
                do     m = 1, 5
                   rhs(m,i,j,k) = rhs(m,i,j,k) - dssp * 
     >                    (  u(m,i,j,k-2) - 4.0d0*u(m,i,j,k-1) + 
     >                     6.0*u(m,i,j,k) - 4.0d0*u(m,i,j,k+1) + 
     >                         u(m,i,j,k+2) )
                end do
             end do
          end do
!$OMP END DO nowait
       end do
 
       k = nz-3
!$OMP DO
       do     j = 1, ny-2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i,j,k-2) - 4.0d0*u(m,i,j,k-1) + 
     >                      6.0d0*u(m,i,j,k) - 4.0d0*u(m,i,j,k+1) )
             end do
          end do
       end do
!$OMP END DO nowait

       k = nz-2
!$OMP DO
       do     j = 1, ny-2
          do     i = 1, nx-2
             do     m = 1, 5
                rhs(m,i,j,k) = rhs(m,i,j,k) - dssp *
     >                    ( u(m,i,j,k-2) - 4.d0*u(m,i,j,k-1) +
     >                      5.d0*u(m,i,j,k) )
             end do
          end do
       end do
!$OMP END DO nowait
!$OMP END PARALLEL
       if (timeron) call timer_stop(t_rhsz)

!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(m,i,j,k)
!$OMP&  SHARED(dt,nx,ny,nz)
       do    k = 1, nz-2
          do    j = 1, ny-2
             do    i = 1, nx-2
                do    m = 1, 5
                   rhs(m,i,j,k) = rhs(m,i,j,k) * dt
                end do
             end do
          end do
       end do
!$OMP END PARALLEL DO
    
       return
       end




