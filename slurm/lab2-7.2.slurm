#!/bin/bash -l
#SBATCH -J matrix-check
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-check-%j.log

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

# README §7.2：所有函数的小规模正确性检查。
srun --cpu-bind=cores ./build/reg_reuse 6 12 24 48 \
  2>&1 | tee results/check_register.txt
srun --cpu-bind=cores ./build/cache_part3 48 6 \
  2>&1 | tee results/check_cache.txt
for opt in 0 1 2 3; do
  srun --cpu-bind=cores "./build/cache_part4_o${opt}" 48 6 \
    2>&1 | tee "results/check_optimal_O${opt}.txt"
done
