#!/bin/bash -l
#SBATCH -J matrix-bonus
#SBATCH -p cpu -N 1 -n 1 -c 1
#SBATCH -t 03:00:00
#SBATCH -o results/lab2-bonus-%j.log

set -euo pipefail
: "${SLURM_JOB_ID:?请使用 sbatch 提交作业，不要在登录节点直接运行}"
cd "${SLURM_SUBMIT_DIR:?请从仓库根目录提交}"
module load "${CMAKE_MODULE:-cmake}"
# Arguments: block_size, repeats, then matrix dimensions.
# Defaults: b=64, repeats=5, n=128/512/1024/2048.
bash bonus/run.sh "$@"
