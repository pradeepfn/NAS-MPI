
c---------------------------------------------------------------------
c---------------------------------------------------------------------

       subroutine z_solve(rho_i, us, vs, ws, speed, qs, u, rhs, 
     $                    nx, nxmax, ny, nz)

c---------------------------------------------------------------------
c---------------------------------------------------------------------

c---------------------------------------------------------------------
c this function performs the solution of the approximate factorization
c step in the z-direction for all five matrix components
c simultaneously. The Thomas algorithm is employed to solve the
c systems for the z-lines. Boundary conditions are non-periodic
c---------------------------------------------------------------------

       include 'header.h'


       integer nx, nxmax, ny, nz
       double precision rho_i(  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  us   (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  vs   (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  ws   (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  speed(  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  qs   (  0:nxmax-1,0:ny-1,0:nz-1), 
     $                  u    (5,0:nxmax-1,0:ny-1,0:nz-1),
     $                  rhs  (5,0:nxmax-1,0:ny-1,0:nz-1)

       integer i, j, k, k1, k2, m
       double precision ru1, fac1, fac2, rtmp(5,0:problem_size)


c---------------------------------------------------------------------
c---------------------------------------------------------------------

       if (timeron) call timer_start(t_zsolve)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(fac2,m,fac1,k2,k1,rtmp,ru1,k,
!$OMP& i,j)
!$OMP&  SHARED(comz6,comz1,comz4,comz5,c2dttz1,dttz1,dttz2,dz1,dzmax,
!$OMP& c1c5,dz5,con43,dz4,c3c4,nz,nx,ny)
       do   j = 1, ny-2
          do   i = 1, nx-2

c---------------------------------------------------------------------
c Computes the left hand side for the three z-factors   
c---------------------------------------------------------------------

c---------------------------------------------------------------------
c first fill the lhs for the u-eigenvalue                          
c---------------------------------------------------------------------

             do   k = 0, nz-1
                ru1 = c3c4*rho_i(i,j,k)
                cv(k) = ws(i,j,k)
                rhos(k) = dmax1(dz4 + con43 * ru1,
     >                          dz5 + c1c5 * ru1,
     >                          dzmax + ru1,
     >                          dz1)
             end do

             call lhsinit(nz-1)
             do   k =  1, nz-2
                lhs(1,k) =  0.0d0
                lhs(2,k) = -dttz2 * cv(k-1) - dttz1 * rhos(k-1)
                lhs(3,k) =  1.0 + c2dttz1 * rhos(k)
                lhs(4,k) =  dttz2 * cv(k+1) - dttz1 * rhos(k+1)
                lhs(5,k) =  0.0d0
             end do

c---------------------------------------------------------------------
c      add fourth order dissipation                                  
c---------------------------------------------------------------------

             k = 1
             lhs(3,k) = lhs(3,k) + comz5
             lhs(4,k) = lhs(4,k) - comz4
             lhs(5,k) = lhs(5,k) + comz1

             k = 2
             lhs(2,k) = lhs(2,k) - comz4
             lhs(3,k) = lhs(3,k) + comz6
             lhs(4,k) = lhs(4,k) - comz4
             lhs(5,k) = lhs(5,k) + comz1

             do    k = 3, nz-4
                lhs(1,k) = lhs(1,k) + comz1
                lhs(2,k) = lhs(2,k) - comz4
                lhs(3,k) = lhs(3,k) + comz6
                lhs(4,k) = lhs(4,k) - comz4
                lhs(5,k) = lhs(5,k) + comz1
             end do

             k = nz-3
             lhs(1,k) = lhs(1,k) + comz1
             lhs(2,k) = lhs(2,k) - comz4
             lhs(3,k) = lhs(3,k) + comz6
             lhs(4,k) = lhs(4,k) - comz4

             k = nz-2
             lhs(1,k) = lhs(1,k) + comz1
             lhs(2,k) = lhs(2,k) - comz4
             lhs(3,k) = lhs(3,k) + comz5


c---------------------------------------------------------------------
c      subsequently, fill the other factors (u+c), (u-c) 
c---------------------------------------------------------------------
             do    k = 1, nz-2
                lhsp(1,k) = lhs(1,k)
                lhsp(2,k) = lhs(2,k) - 
     >                            dttz2 * speed(i,j,k-1)
                lhsp(3,k) = lhs(3,k)
                lhsp(4,k) = lhs(4,k) + 
     >                            dttz2 * speed(i,j,k+1)
                lhsp(5,k) = lhs(5,k)
                lhsm(1,k) = lhs(1,k)
                lhsm(2,k) = lhs(2,k) + 
     >                            dttz2 * speed(i,j,k-1)
                lhsm(3,k) = lhs(3,k)
                lhsm(4,k) = lhs(4,k) - 
     >                            dttz2 * speed(i,j,k+1)
                lhsm(5,k) = lhs(5,k)
             end do


c---------------------------------------------------------------------
c Load a row of K data
c---------------------------------------------------------------------

             do   k = 0, nz-1
	        rtmp(1,k) = rhs(1,i,j,k)
	        rtmp(2,k) = rhs(2,i,j,k)
	        rtmp(3,k) = rhs(3,i,j,k)
	        rtmp(4,k) = rhs(4,i,j,k)
	        rtmp(5,k) = rhs(5,i,j,k)
	     end do

c---------------------------------------------------------------------
c                          FORWARD ELIMINATION  
c---------------------------------------------------------------------

             do    k = 0, nz-3
                k1 = k  + 1
                k2 = k  + 2
                fac1      = 1.d0/lhs(3,k)
                lhs(4,k)  = fac1*lhs(4,k)
                lhs(5,k)  = fac1*lhs(5,k)
                do    m = 1, 3
                   rtmp(m,k) = fac1*rtmp(m,k)
                end do
                lhs(3,k1) = lhs(3,k1) -
     >                         lhs(2,k1)*lhs(4,k)
                lhs(4,k1) = lhs(4,k1) -
     >                         lhs(2,k1)*lhs(5,k)
                do    m = 1, 3
                   rtmp(m,k1) = rtmp(m,k1) -
     >                         lhs(2,k1)*rtmp(m,k)
                end do
                lhs(2,k2) = lhs(2,k2) -
     >                         lhs(1,k2)*lhs(4,k)
                lhs(3,k2) = lhs(3,k2) -
     >                         lhs(1,k2)*lhs(5,k)
                do    m = 1, 3
                   rtmp(m,k2) = rtmp(m,k2) -
     >                         lhs(1,k2)*rtmp(m,k)
                end do
             end do

c---------------------------------------------------------------------
c      The last two rows in this zone are a bit different, 
c      since they do not have two more rows available for the
c      elimination of off-diagonal entries
c---------------------------------------------------------------------
             k  = nz-2
             k1 = nz-1
             fac1      = 1.d0/lhs(3,k)
             lhs(4,k)  = fac1*lhs(4,k)
             lhs(5,k)  = fac1*lhs(5,k)
             do    m = 1, 3
                rtmp(m,k) = fac1*rtmp(m,k)
             end do
             lhs(3,k1) = lhs(3,k1) -
     >                      lhs(2,k1)*lhs(4,k)
             lhs(4,k1) = lhs(4,k1) -
     >                      lhs(2,k1)*lhs(5,k)
             do    m = 1, 3
                rtmp(m,k1) = rtmp(m,k1) -
     >                      lhs(2,k1)*rtmp(m,k)
             end do
c---------------------------------------------------------------------
c               scale the last row immediately
c---------------------------------------------------------------------
             fac2      = 1.d0/lhs(3,k1)
             do    m = 1, 3
                rtmp(m,k1) = fac2*rtmp(m,k1)
             end do

c---------------------------------------------------------------------
c      do the u+c and the u-c factors               
c---------------------------------------------------------------------
             do    k = 0, nz-3
             	k1 = k  + 1
             	k2 = k  + 2
	     	m = 4
             	fac1	   = 1.d0/lhsp(3,k)
             	lhsp(4,k)  = fac1*lhsp(4,k)
             	lhsp(5,k)  = fac1*lhsp(5,k)
             	rtmp(m,k)  = fac1*rtmp(m,k)
             	lhsp(3,k1) = lhsp(3,k1) -
     >       		    lhsp(2,k1)*lhsp(4,k)
             	lhsp(4,k1) = lhsp(4,k1) -
     >       		    lhsp(2,k1)*lhsp(5,k)
             	rtmp(m,k1) = rtmp(m,k1) -
     >       		    lhsp(2,k1)*rtmp(m,k)
             	lhsp(2,k2) = lhsp(2,k2) -
     >       		    lhsp(1,k2)*lhsp(4,k)
             	lhsp(3,k2) = lhsp(3,k2) -
     >       		    lhsp(1,k2)*lhsp(5,k)
             	rtmp(m,k2) = rtmp(m,k2) -
     >       		    lhsp(1,k2)*rtmp(m,k)
	     	m = 5
             	fac1	   = 1.d0/lhsm(3,k)
             	lhsm(4,k)  = fac1*lhsm(4,k)
             	lhsm(5,k)  = fac1*lhsm(5,k)
             	rtmp(m,k)  = fac1*rtmp(m,k)
             	lhsm(3,k1) = lhsm(3,k1) -
     >       		    lhsm(2,k1)*lhsm(4,k)
             	lhsm(4,k1) = lhsm(4,k1) -
     >       		    lhsm(2,k1)*lhsm(5,k)
             	rtmp(m,k1) = rtmp(m,k1) -
     >       		    lhsm(2,k1)*rtmp(m,k)
             	lhsm(2,k2) = lhsm(2,k2) -
     >       		    lhsm(1,k2)*lhsm(4,k)
             	lhsm(3,k2) = lhsm(3,k2) -
     >       		    lhsm(1,k2)*lhsm(5,k)
             	rtmp(m,k2) = rtmp(m,k2) -
     >       		    lhsm(1,k2)*rtmp(m,k)
             end do

c---------------------------------------------------------------------
c         And again the last two rows separately
c---------------------------------------------------------------------
             k  = nz-2
             k1 = nz-1
	     m = 4
             fac1	= 1.d0/lhsp(3,k)
             lhsp(4,k)  = fac1*lhsp(4,k)
             lhsp(5,k)  = fac1*lhsp(5,k)
             rtmp(m,k)  = fac1*rtmp(m,k)
             lhsp(3,k1) = lhsp(3,k1) -
     >       		 lhsp(2,k1)*lhsp(4,k)
             lhsp(4,k1) = lhsp(4,k1) -
     >       		 lhsp(2,k1)*lhsp(5,k)
             rtmp(m,k1) = rtmp(m,k1) -
     >       		 lhsp(2,k1)*rtmp(m,k)
	     m = 5
             fac1	= 1.d0/lhsm(3,k)
             lhsm(4,k)  = fac1*lhsm(4,k)
             lhsm(5,k)  = fac1*lhsm(5,k)
             rtmp(m,k)  = fac1*rtmp(m,k)
             lhsm(3,k1) = lhsm(3,k1) -
     >       		 lhsm(2,k1)*lhsm(4,k)
             lhsm(4,k1) = lhsm(4,k1) -
     >       		 lhsm(2,k1)*lhsm(5,k)
             rtmp(m,k1) = rtmp(m,k1) -
     >       		 lhsm(2,k1)*rtmp(m,k)
c---------------------------------------------------------------------
c               Scale the last row immediately (some of this is overkill
c               if this is the last cell)
c---------------------------------------------------------------------
             rtmp(4,k1) = rtmp(4,k1)/lhsp(3,k1)
             rtmp(5,k1) = rtmp(5,k1)/lhsm(3,k1)


c---------------------------------------------------------------------
c                         BACKSUBSTITUTION 
c---------------------------------------------------------------------

             k  = nz-2
             k1 = nz-1
             do   m = 1, 3
                rtmp(m,k) = rtmp(m,k) -
     >                             lhs(4,k)*rtmp(m,k1)
             end do

             rtmp(4,k) = rtmp(4,k) -
     >                             lhsp(4,k)*rtmp(4,k1)
             rtmp(5,k) = rtmp(5,k) -
     >                             lhsm(4,k)*rtmp(5,k1)

c---------------------------------------------------------------------
c      The first three factors
c---------------------------------------------------------------------
             do   k = nz-3, 0, -1
                k1 = k  + 1
                k2 = k  + 2
                do   m = 1, 3
                   rtmp(m,k) = rtmp(m,k) - 
     >                          lhs(4,k)*rtmp(m,k1) -
     >                          lhs(5,k)*rtmp(m,k2)
                end do

c---------------------------------------------------------------------
c      And the remaining two
c---------------------------------------------------------------------
                rtmp(4,k) = rtmp(4,k) - 
     >                          lhsp(4,k)*rtmp(4,k1) -
     >                          lhsp(5,k)*rtmp(4,k2)
                rtmp(5,k) = rtmp(5,k) - 
     >                          lhsm(4,k)*rtmp(5,k1) -
     >                          lhsm(5,k)*rtmp(5,k2)
             end do

c---------------------------------------------------------------------
c      Store result
c---------------------------------------------------------------------
             do   k = 0, nz-1
	        rhs(1,i,j,k) = rtmp(1,k)
	        rhs(2,i,j,k) = rtmp(2,k)
	        rhs(3,i,j,k) = rtmp(3,k)
	        rhs(4,i,j,k) = rtmp(4,k)
	        rhs(5,i,j,k) = rtmp(5,k)
	     end do

          end do
       end do
!$OMP END PARALLEL DO
       if (timeron) call timer_stop(t_zsolve)

       if (timeron) call timer_start(t_tzetar)
       call tzetar(us, vs, ws, speed, qs, u, rhs, nx, nxmax, ny, nz)
       if (timeron) call timer_stop(t_tzetar)

       return
       end
    






