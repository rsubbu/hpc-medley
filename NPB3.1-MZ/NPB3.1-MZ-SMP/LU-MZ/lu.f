!-------------------------------------------------------------------------!
!                                                                         !
!        N  A  S     P A R A L L E L     B E N C H M A R K S  3.1         !
!                                                                         !
!             S M P    M U L T I - Z O N E    V E R S I O N               !
!                                                                         !
!                           L U - M Z - S M P                             !
!                                                                         !
!-------------------------------------------------------------------------!
!                                                                         !
!    This benchmark is a serial version of the NPB LU code.               !
!    Refer to NAS Technical Reports 95-020 for details.                   !
!                                                                         !
!    Permission to use, copy, distribute and modify this software         !
!    for any purpose with or without fee is hereby granted.  We           !
!    request, however, that all derived work reference the NAS            !
!    Parallel Benchmarks 3.1. This software is provided "as is"           !
!    without express or implied warranty.                                 !
!                                                                         !
!    Information on NPB 3.1, including the technical report, the          !
!    original specifications, source code, results and information        !
!    on how to submit new results, is available at:                       !
!                                                                         !
!           http://www.nas.nasa.gov/Software/NPB/                         !
!                                                                         !
!    Send comments or suggestions to  npb@nas.nasa.gov                    !
!                                                                         !
!          NAS Parallel Benchmarks Group                                  !
!          NASA Ames Research Center                                      !
!          Mail Stop: T27A-1                                              !
!          Moffett Field, CA   94035-1000                                 !
!                                                                         !
!          E-mail:  npb@nas.nasa.gov                                      !
!          Fax:     (650) 604-3957                                        !
!                                                                         !
!-------------------------------------------------------------------------!

c---------------------------------------------------------------------
c
c Authors: S. Weeratunga
c          V. Venkatakrishnan
c          E. Barszcz
c          M. Yarrow
C          R.F. Van der Wijngaart
C          H. Jin
c
c---------------------------------------------------------------------

c---------------------------------------------------------------------
      program applu
c---------------------------------------------------------------------

c---------------------------------------------------------------------
c
c   driver for the performance evaluation of the solver for
c   five coupled parabolic/elliptic partial differential equations.
c
c---------------------------------------------------------------------

      implicit none

      include 'header.h'
      include 'smp_stuff.h'

      integer num_zones
      parameter (num_zones=x_zones*y_zones)
      integer proc_max_size
      parameter (proc_max_size=max_xysize*gz_size)

      integer nx(num_zones), nxmax(num_zones), ny(num_zones), 
     $        nz(num_zones), start1(num_zones), start5(num_zones),
     $        qstart_west(num_zones),  qstart_east(num_zones),
     $        qstart_south(num_zones), qstart_north(num_zones)

c---------------------------------------------------------------------
c   Define all field arrays as one-dimenional arrays, to be reshaped
c---------------------------------------------------------------------

      double precision u    (5*proc_max_size),
     >                 rsd  (5*proc_max_size),
     >                 frct (5*proc_max_size),
     >                 qs   (  proc_max_size),
     >                 rho_i(  proc_max_size)

      common/cvar/ u, rsd, frct, qs, rho_i

c---------------------------------------------------------------------
c   2D auxiliary arrays are dimensioned to accommodate the largest
c   zone cross section
c---------------------------------------------------------------------

      double precision a (25*problem_size*problem_size), 
     $                 b (25*problem_size*problem_size), 
     $                 c (25*problem_size*problem_size), 
     $                 d (25*problem_size*problem_size),
     $                 au(25*problem_size*problem_size), 
     $                 bu(25*problem_size*problem_size), 
     $                 cu(25*problem_size*problem_size), 
     $                 du(25*problem_size*problem_size),
     $                 phi1 (problem_size*problem_size),
     $                 phi2 (problem_size*problem_size)

      common/cjac/ a, b, c, d, au, bu, cu, du, phi1, phi2

      logical verified
      double precision mflops, navg, nsur

      integer i, fstatus, zone, step, n3, iz, ip, tot_threads
      double precision t, tmax, timer_read, trecs(t_last),
     $                 rsdnm(5), rsdnm_aux(5), errnm(5), errnm_aux(5),
     $                 frc, frc_aux
      external timer_read
      character t_names(t_last)*8

c---------------------------------------------------------------------
c     Setup info for timers
c---------------------------------------------------------------------

      open (unit=2,file='timer.flag',status='old',iostat=fstatus)
      if (fstatus .eq. 0) then
         timeron = .true.
         t_names(t_total)  = 'total'
         t_names(t_rhsx)   = 'rhsx'
         t_names(t_rhsy)   = 'rhsy'
         t_names(t_rhsz)   = 'rhsz'
         t_names(t_rhs)    = 'rhs'
         t_names(t_jacld)  = 'jacld'
         t_names(t_blts)   = 'blts'
         t_names(t_jacu)   = 'jacu'
         t_names(t_buts)   = 'buts'
         t_names(t_add)    = 'add'
         t_names(t_l2norm) = 'l2norm'
         t_names(t_rdis1)  = 'qbc_copy'
         t_names(t_rdis2)  = 'qbc_comm'
         close(2)
      else
         timeron = .false.
      endif

c---------------------------------------------------------------------
c   read input data
c---------------------------------------------------------------------
      call read_input(tot_threads)

c---------------------------------------------------------------------
c   set up domain sizes
c---------------------------------------------------------------------
      call zone_setup(nx, nxmax, ny, nz, 
     $                qstart_west,  qstart_east, 
     $                qstart_south, qstart_north)

      call smp_setup(num_zones, nx, ny, nz, tot_threads)
      call zone_starts(num_zones, nxmax, ny, nz, start1, start5)

c---------------------------------------------------------------------
c   set up coefficients
c---------------------------------------------------------------------
      call setcoeff()

      do i = 1, t_last
      	 call timer_clear(i)
      end do

      do iz = 1, proc_num_zones
        zone = proc_zone_id(iz)

c---------------------------------------------------------------------
c   set the boundary values for dependent variables
c---------------------------------------------------------------------
        call setbv(u(start5(iz)),
     $             nx(zone), nxmax(zone), ny(zone), nz(zone))

c---------------------------------------------------------------------
c   set the initial values for dependent variables
c---------------------------------------------------------------------
        call setiv(u(start5(iz)),
     $             nx(zone), nxmax(zone), ny(zone), nz(zone))

c---------------------------------------------------------------------
c   compute the forcing term based on prescribed exact solution
c---------------------------------------------------------------------
        call erhs(frct(start5(iz)), rsd(start5(iz)),
     $            nx(zone), nxmax(zone), ny(zone), nz(zone))

c---------------------------------------------------------------------
c   compute the steady-state residuals
c---------------------------------------------------------------------
        call rhs(u(start5(iz)), rsd(start5(iz)), 
     $           frct(start5(iz)), qs(start1(iz)), 
     $           rho_i(start1(iz)), 
     $           nx(zone), nxmax(zone), ny(zone), nz(zone))

      end do

c---------------------------------------------------------------------
c   initialize a,b,c,d to zero (guarantees that page tables have been
c   formed, if applicable on given architecture, before timestepping).
c   extra working arrays au, bu, cu, du are used in the OpenMP version
c   to align/touch data pages properly in the upper triangular solver.
c---------------------------------------------------------------------
      zone = proc_zone_id(1)
      call init_workarray(nx(zone), nxmax(zone), ny(zone),
     $               	  a, b, c, d, au, bu, cu, du)

c---------------------------------------------------------------------
c   perform one SSOR iteration to touch all data pages
c---------------------------------------------------------------------
      call exch_qbc(u, nx, nxmax, ny, nz, start5, qstart_west,  
     $              qstart_east, qstart_south, qstart_north)

      do iz = 1, proc_num_zones
        zone = proc_zone_id(iz)
        call ssor(u(start5(iz)), rsd(start5(iz)), 
     $            frct(start5(iz)), qs(start1(iz)), 
     $            rho_i(start1(iz)), 
     $            a, b, c, d, au, bu, cu, du, 
     $            nx(zone), nxmax(zone), ny(zone), nz(zone))
      end do

c---------------------------------------------------------------------
c   reset the boundary and initial values
c---------------------------------------------------------------------
      do iz = 1, proc_num_zones
        zone = proc_zone_id(iz)

        call setbv(u(start5(iz)),
     $             nx(zone), nxmax(zone), ny(zone), nz(zone))

        call setiv(u(start5(iz)),
     $             nx(zone), nxmax(zone), ny(zone), nz(zone))

c---------------------------------------------------------------------
c   compute the steady-state residuals
c---------------------------------------------------------------------
        call rhs(u(start5(iz)), rsd(start5(iz)), 
     $           frct(start5(iz)), qs(start1(iz)), 
     $           rho_i(start1(iz)), 
     $           nx(zone), nxmax(zone), ny(zone), nz(zone))

      end do

c---------------------------------------------------------------------
c   begin pseudo-time stepping iterations
c---------------------------------------------------------------------

      do i = 1, t_last
      	 call timer_clear(i)
      end do

      call smp_barrier
      call timer_start(1)

c---------------------------------------------------------------------
c   the timestep loop
c---------------------------------------------------------------------
      do step = 1, itmax

        if (mod(step,20) .eq. 0 .or. step .eq. 1 .or.
     >        step .eq. itmax) then
           if (myid .eq. root) write( *, 200) step
 200       format(' Time step ', i4)
        endif

        call exch_qbc(u, nx, nxmax, ny, nz, start5, qstart_west,  
     $                qstart_east, qstart_south, qstart_north)

c---------------------------------------------------------------------
c   perform the SSOR iterations
c---------------------------------------------------------------------

        do iz = 1, proc_num_zones
          zone = proc_zone_id(iz)
          call ssor(u(start5(iz)), rsd(start5(iz)), 
     $              frct(start5(iz)), qs(start1(iz)), 
     $              rho_i(start1(iz)), 
     $              a, b, c, d, au, bu, cu, du, 
     $              nx(zone), nxmax(zone), ny(zone), nz(zone))
        end do

      end do
 
      do i = 1, 5
         rsdnm(i) = 0.d0
         errnm(i) = 0.d0
      end do
      frc = 0.d0

c---------------------------------------------------------------------
c   compute the max-norms of newton iteration residuals
c---------------------------------------------------------------------
      if (timeron) call timer_start(t_l2norm)
      do iz = 1, proc_num_zones
        zone = proc_zone_id(iz)
        call l2norm(rsd(start5(iz)), rsdnm_aux, 
     $              nx(zone), nxmax(zone), ny(zone), nz(zone))
        do i = 1, 5
          rsdnm(i) = rsdnm(i) + rsdnm_aux(i)
        end do
      end do

      do i = 1, 5
         sbuffer(i,myid) = rsdnm(i)
      end do
      if (timeron) call timer_stop(t_l2norm)

      call timer_stop(1)
      maxtime= timer_read(1)

c---------------------------------------------------------------------
c   compute the solution error and surface integral
c---------------------------------------------------------------------
      do iz = 1, proc_num_zones
        zone = proc_zone_id(iz)
        call error(u(start5(iz)), errnm_aux,
     $             nx(zone), nxmax(zone), ny(zone), nz(zone))
        call pintgr(u(start5(iz)), phi1, phi2, frc_aux,
     $              nx(zone), nxmax(zone), ny(zone), nz(zone))
        do i = 1, 5
          errnm(i) = errnm(i) + errnm_aux(i)
        end do
        frc = frc + frc_aux
      end do

      do i = 1, 5
         sbuffer(i+5,myid) = errnm(i)
      end do
      sbuffer(11,myid) = frc
c
      call smp_barrier
c
      do ip = 0, num_procs-1
        if (ip .ne. myid) then
           do i = 1, 5
             rsdnm(i) = rsdnm(i) + sbuffer(i,ip)
             errnm(i) = errnm(i) + sbuffer(i+5,ip)
           end do
           frc = frc + sbuffer(11,ip)
        endif
      end do

c---------------------------------------------------------------------
c   verification test
c---------------------------------------------------------------------
      if (myid .eq. root) then
        call verify ( rsdnm, errnm, frc, verified )
      endif

      sbuffer(12,myid) = maxtime
      call smp_barrier
      do ip = 0, num_procs-1
         if (ip .ne. myid) then
            maxtime = max(maxtime, sbuffer(12,ip))
         endif
      end do

      if (myid .ne. root) goto 900

      mflops = 0.d0

      if (maxtime .ne. 0.d0) then
        do zone = 1, num_zones
          n3 = nx(zone)*ny(zone)*nz(zone)
          navg = (nx(zone) + ny(zone) + nz(zone))/3.d0
	  nsur = (nx(zone)*ny(zone) + nx(zone)*nz(zone) +
     >            ny(zone)*nz(zone))/3.d0
          mflops = mflops + float(itmax)*1.0d-6*
     >       (1984.77d0*float(n3) - 10923.3d0*nsur
     >         + 27770.9d0*navg - 144010.d0)
     >       / maxtime
        end do
      endif

      call print_results('LU-MZ', class, gx_size, gy_size, gz_size, 
     >  itmax, maxtime, mflops, num_procs, tot_threads,
     >  '          floating point', verified, 
     >  npbversion, compiletime, cs1, cs2, cs3, cs4, cs5, cs6, 
     >  '(none)')

c---------------------------------------------------------------------
c      More timers
c---------------------------------------------------------------------
 900  if (.not.timeron) goto 999

      do i=1, t_last
         trecs(i) = timer_read(i)
      end do
      tmax = maxtime
      if (tmax .eq. 0.0) tmax = 1.0

      if (myid .gt. 0) then
         call smp_wait(0, 0)
         do i=1, t_last
            sbuffer(i, 0) = trecs(i)
         end do
         call smp_signal(0, 0)
         goto 999
      endif

      ip = 0
 910  write(*,800) ip, proc_num_threads(ip+1)
 800  format(' Myid =',i5,'   num_threads =',i4/
     >       '  SECTION   Time (secs)')
      do i=1, t_last
         write(*,810) t_names(i), trecs(i), trecs(i)*100./tmax
         if (i.eq.t_rhs) then
            t = trecs(t_rhsx) + trecs(t_rhsy) + trecs(t_rhsz)
            write(*,820) 'sub-rhs', t, t*100./tmax
            t = trecs(i) - t
            write(*,820) 'rest-rhs', t, t*100./tmax
         elseif (i.eq.t_rdis2) then
            t = trecs(t_rdis1) + trecs(t_rdis2)
            write(*,820) 'exch_qbc', t, t*100./tmax
         endif
 810     format(2x,a8,':',f9.3,'  (',f6.2,'%)')
 820     format(5x,'--> total ',a8,':',f9.3,'  (',f6.2,'%)')
      end do

      ip = ip + 1
      if (ip .lt. num_procs) then
         write(*,*)
         call smp_signal(ip, 0)
         call smp_wait(ip, 0)
         do i=1, t_last
            trecs(i) = sbuffer(i, 0)
         end do
         goto 910
      endif

 999  continue
      call smp_finish
      end

c---------------------------------------------------------------------
c---------------------------------------------------------------------

      subroutine init_workarray(nx, nxmax, ny, a, b, c, d, 
     $                          au, bu, cu, du)
      implicit none

c---------------------------------------------------------------------
c   initialize a,b,c,d to zero (guarantees that page tables have been
c   formed, if applicable on given architecture, before timestepping).
c   extra working arrays au, bu, cu, du are used in the OpenMP version
c   to align/touch data pages properly in the upper triangular solver.
c---------------------------------------------------------------------

      integer nx, nxmax, ny
      double precision a (25,2:nxmax-1,ny), b (25,2:nxmax-1,ny),
     $                 c (25,2:nxmax-1,ny), d (25,2:nxmax-1,ny),
     $                 au(25,2:nxmax-1,ny), bu(25,2:nxmax-1,ny),
     $                 cu(25,2:nxmax-1,ny), du(25,2:nxmax-1,ny)

      integer i, j, m

!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m)
!$OMP DO
      do j = 2, ny-1
        do i = 2, nx-1
	  do m = 1, 25
            a(m,i,j) = 0.d0
            b(m,i,j) = 0.d0
            c(m,i,j) = 0.d0
            d(m,i,j) = 0.d0
          end do
        end do
      end do
!$OMP END DO nowait
!$OMP DO
      do j = ny-1, 2, -1
        do i = nx-1, 2, -1
	  do m = 1, 25
            au(m,i,j) = 0.d0
            bu(m,i,j) = 0.d0
            cu(m,i,j) = 0.d0
            du(m,i,j) = 0.d0
          end do
        end do
      end do
!$OMP END DO nowait
!$OMP END PARALLEL

      return
      end
