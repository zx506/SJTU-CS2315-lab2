#!/bin/bash -l
#SBATCH -J matrix-confirm
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-block-confirm-%j.log

set -euo pipefail
: "${SLURM_JOB_ID:?请使用 sbatch 提交作业，不要在登录节点直接运行}"

if (( $# != 2 )); then
  echo "用法：sbatch slurm/lab2-8.5-block-confirm.slurm 候选b1 候选b2" >&2
  exit 2
fi
for b in "$@"; do
  case "$b" in
    16|32|64|128|256) ;;
    *) echo "块大小必须从 16、32、64、128、256 中选择。" >&2; exit 2 ;;
  esac
done

if [[ "$1" == "$2" ]]; then
  echo "请传入两个不同的候选块大小。" >&2
  exit 2
fi

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

# README §8.5：传入在 n=1024 时选出的两个候选值。
: > results/cache_block_2048.txt
for b in "$@"; do
  echo "===== n=2048, block_size=${b} =====" | tee -a results/cache_block_2048.txt
  srun --cpu-bind=cores ./build/cache_part3 2048 "$b" \
    2>&1 | tee -a results/cache_block_2048.txt
done
