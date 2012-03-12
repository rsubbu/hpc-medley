c CLASS = S
c  
c  
c  This file is generated automatically by the setparams utility.
c  It sets the number of processors and the class of the NPB
c  in this directory. Do not modify it by hand.
c  
        integer problem_size, niter_default
        parameter (problem_size=12, niter_default=100)
        double precision dt_default
        parameter (dt_default = 0.015d0)
        logical  convertdouble
        parameter (convertdouble = .false.)
        character*11 compiletime
        parameter (compiletime='05 Mar 2012')
        character*3 npbversion
        parameter (npbversion='3.1')
        character*6 cs1
        parameter (cs1='mpif77')
        character*6 cs2
        parameter (cs2='$(F77)')
        character*23 cs3
        parameter (cs3='-L/usr/local/lib -lmpi ')
        character*20 cs4
        parameter (cs4='-I/usr/local/include')
        character*28 cs5
        parameter (cs5='-O3 -fopenmp -mcmodel=medium')
        character*28 cs6
        parameter (cs6='-O3 -fopenmp -mcmodel=medium')
        character*6 cs7
        parameter (cs7='randi8')
