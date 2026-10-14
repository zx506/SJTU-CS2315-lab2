#!/bin/bash -l
#SBATCH -J matrix-sweep
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-block-sweep-%j.log

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

# README §8.5：固定 n=1024，筛选全部五个候选块大小。
: > results/cache_block_sweep.txt
for b in 16 32 64 128 256; do
  echo "===== block_size=${b} =====" | tee -a results/cache_block_sweep.txt
  srun --cpu-bind=cores ./build/cache_part3 1024 "$b" \
    2>&1 | tee -a results/cache_block_sweep.txt
done
