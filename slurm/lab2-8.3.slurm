#!/bin/bash -l
#SBATCH -J matrix-register
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-register-%j.log

set -euo pipefail
: "${SLURM_JOB_ID:?请使用 sbatch 提交作业，不要在登录节点直接运行}"

cd "${SLURM_SUBMIT_DIR:?请从仓库根目录提交}"
module load "${CMAKE_MODULE:-cmake}"
cmake -S . -B build
cmake --build build -j1
(cd build && ctest --output-on-failure)
mkdir -p results

{
  printf 'JobID: %s\n' "$SLURM_JOB_ID"
  hostname
  lscpu
  gcc --version
  cmake --version
  uname -a
} | tee results/environment.txt

# README §8.3：所有规模均能被 6 整除。
srun --cpu-bind=cores ./build/reg_reuse 66 126 258 510 1026 2046 \
  2>&1 | tee results/register_reuse.txt
