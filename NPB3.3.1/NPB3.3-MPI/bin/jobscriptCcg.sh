#!/bin/sh
#PBS -l walltime=02:00:00
#PBS -N cg.C
#PBS -q normal
#PBS -l nodes=32:ppn=12
#PBS -m bea
#PBS -M moussa.taifi@temple.edu
#PBS -o cg.log
#PBS -o cg.err

cd $PBS_O_WORKDIR
cat $PBS_NODEFILE > nodefile.txt
python parsenodefile.py nodefile.txt

mpirun -n 2 -npernode 1 -hostfile myhostfile.txt  ./cg.C.2   | tee cg.C.2.n2.p1-results.txt;
mpirun -n 2 -npernode 2 -hostfile myhostfile.txt  ./cg.C.4   | tee cg.C.8.n2.p2-results.txt;
mpirun -n 2 -npernode 4 -hostfile myhostfile.txt  ./cg.C.8   | tee cg.C.8.n2.p4-results.txt;
mpirun -n 2 -npernode 8 -hostfile myhostfile.txt  ./cg.C.16  | tee cg.C.16.n2.p8-results.txt;
mpirun -n 2 -npernode 12 -hostfile myhostfile.txt ./cg.C.16  | tee cg.C.16.n2.p12-results.txt;

mpirun -n 4 -npernode 1 -hostfile myhostfile.txt  ./cg.C.4   | tee cg.C.4.n4.p1-results.txt;
mpirun -n 4 -npernode 2 -hostfile myhostfile.txt  ./cg.C.8   | tee cg.C.8.n4.p2-results.txt;
mpirun -n 4 -npernode 4 -hostfile myhostfile.txt  ./cg.C.16   | tee cg.C.16.n4.p4-results.txt;
mpirun -n 4 -npernode 8 -hostfile myhostfile.txt  ./cg.C.32  | tee cg.C.32.n4.p8-results.txt;
mpirun -n 4 -npernode 12 -hostfile myhostfile.txt ./cg.C.32  | tee cg.C.32.n4.p12-results.txt;

mpirun -n 8 -npernode 1 -hostfile myhostfile.txt  ./cg.C.8   | tee cg.C.8.n8.p1-results.txt;
mpirun -n 8 -npernode 2 -hostfile myhostfile.txt  ./cg.C.16   | tee cg.C.16.n8.p2-results.txt;
mpirun -n 8 -npernode 4 -hostfile myhostfile.txt  ./cg.C.32   | tee cg.C.32.n8.p4-results.txt;
mpirun -n 8 -npernode 8 -hostfile myhostfile.txt  ./cg.C.64  | tee cg.C.64.n8.p8-results.txt;
mpirun -n 8 -npernode 12 -hostfile myhostfile.txt ./cg.C.64  | tee cg.C.64.n8.p12-results.txt;

mpirun -n 16 -npernode 1 -hostfile myhostfile.txt  ./cg.C.16   | tee cg.C.8.n16.p1-results.txt;
mpirun -n 16 -npernode 2 -hostfile myhostfile.txt  ./cg.C.32   | tee cg.C.16.n16.p2-results.txt;
mpirun -n 16 -npernode 4 -hostfile myhostfile.txt  ./cg.C.64   | tee cg.C.32.n16.p4-results.txt;
mpirun -n 16 -npernode 8 -hostfile myhostfile.txt  ./cg.C.128  | tee cg.C.64.n16.p8-results.txt;
mpirun -n 16 -npernode 12 -hostfile myhostfile.txt ./cg.C.128  | tee cg.C.64.n16.p12-results.txt;

mpirun -n 32 -npernode 1 -hostfile myhostfile.txt ./cg.C.32 | tee cg.C.32.n32.p1-results.txt;
mpirun -n 32 -npernode 2 -hostfile myhostfile.txt ./cg.C.64 | tee cg.C.64.n32.p2-results.txt;
mpirun -n 32 -npernode 4 -hostfile myhostfile.txt ./cg.C.128 | tee cg.C.128.n32.p4-results.txt;
mpirun -n 32 -npernode 8 -hostfile myhostfile.txt ./cg.C.256 | tee cg.C.256.n32.p8-results.txt;
mpirun -n 32 -npernode 12 -hostfile myhostfile.txt ./cg.C.256 | tee cg.C.256.n32.p12-results.txt;


