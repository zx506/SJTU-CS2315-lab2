#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

block_size="${1:-64}"
repeats="${2:-5}"
if (( $# >= 2 )); then shift 2; elif (( $# == 1 )); then shift; fi
sizes=("$@")
if (( ${#sizes[@]} == 0 )); then sizes=(128 512 1024 2048); fi
for value in "$block_size" "$repeats" "${sizes[@]}"; do
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "用法：bash bonus/run.sh [b [重复次数 [n1 n2 ...]]]，参数须为正整数。" >&2
    exit 2
  fi
done
if (( ${#repeats} > 3 )) || (( repeats < 5 || repeats > 101 )); then
  echo "正式测量的重复次数须为 5 到 101。" >&2
  exit 2
fi

# Cover common BLAS runtimes; verify actual threading for the installed backend.
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 OMP_DYNAMIC=FALSE MKL_DYNAMIC=FALSE
system_blas="${BONUS_SYSTEM_BLAS:-OFF}"
native="${BONUS_NATIVE:-OFF}"
case "$system_blas/$native" in
  OFF/OFF|OFF/ON|ON/OFF|ON/ON) ;;
  *) echo "BONUS_SYSTEM_BLAS 和 BONUS_NATIVE 只能为 ON 或 OFF。" >&2; exit 2 ;;
esac
tag="${SLURM_JOB_ID:-local-$(date +%Y%m%d-%H%M%S)-$$}"
result_dir="results/bonus-$tag"
mkdir -p "$result_dir"
{
  hostname
  uname -a
  if command -v lscpu >/dev/null; then lscpu; fi
  cmake --version
  printf 'BONUS_SYSTEM_BLAS=%s BONUS_NATIVE=%s\n' "$system_blas" "$native"
  printf 'b=%s repeats=%s sizes=%s\n' "$block_size" "$repeats" "${sizes[*]}"
  env | sort | sed -n '/_NUM_THREADS=/p; /_MAXIMUM_THREADS=/p; /_DYNAMIC=/p'
} | tee "$result_dir/environment.txt"

cmake -S . -B build-bonus -DLAB_BUILD_BONUS=ON -DBUILD_TESTING=ON \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DLAB_USE_SYSTEM_BLAS="$system_blas" -DLAB_BONUS_NATIVE="$native" \
  2>&1 | tee "$result_dir/configure.txt"
cmake --build build-bonus --target bonus_gemm --verbose -j1 \
  2>&1 | tee "$result_dir/build.txt"
cp build-bonus/CMakeCache.txt "$result_dir/CMakeCache.txt"
cp build-bonus/compile_commands.json "$result_dir/compile_commands.json"
compiler=$(sed -n 's/^CMAKE_C_COMPILER:FILEPATH=//p' build-bonus/CMakeCache.txt)
if [[ -n "$compiler" ]]; then "$compiler" --version | tee -a "$result_dir/environment.txt"; fi

launcher=()
if [[ -n "${SLURM_JOB_ID:-}" ]]; then launcher=(srun --cpu-bind=cores); fi
"${launcher[@]}" ./build-bonus/bonus/bonus_gemm --check \
  2>&1 | tee "$result_dir/correctness.txt"
for n in "${sizes[@]}"; do
  "${launcher[@]}" ./build-bonus/bonus/bonus_gemm "$n" "$block_size" "$repeats" \
    2>&1 | tee "$result_dir/n-${n}.txt"
done
printf '结果目录：%s\n' "$result_dir"
