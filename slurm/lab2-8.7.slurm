#!/bin/bash -l
#SBATCH -J matrix-repeat
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-repeat-%j.log

set -euo pipefail
: "${SLURM_JOB_ID:?请使用 sbatch 提交作业，不要在登录节点直接运行}"

if (( $# != 1 )); then
  echo "用法：sbatch slurm/lab2-8.7.slurm 最佳b" >&2
  exit 2
fi
for b in "$@"; do
  case "$b" in
    16|32|64|128|256) ;;
    *) echo "块大小必须从 16、32、64、128、256 中选择。" >&2; exit 2 ;;
  esac
done

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

# README §8.7：以 O3 为例，按同一配置重复三次。
best_b="$1"
: > results/optimal_O3_repeated.txt
for run in 1 2 3; do
  echo "===== run=${run} =====" | tee -a results/optimal_O3_repeated.txt
  srun --cpu-bind=cores ./build/cache_part4_o3 2048 "$best_b" \
    2>&1 | tee -a results/optimal_O3_repeated.txt
done
