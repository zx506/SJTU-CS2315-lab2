# Lab 2：矩阵乘法性能优化实验

## 1. 实验任务


你需要在框架的 `src/mygemm.c` 中实现多种矩阵乘法算法，依次完成：

1. 基础矩阵乘法和寄存器复用；
2. 2×2 或更大的寄存器分块；
3. 六种循环次序；
4. 六种缓存分块实现；
5. 缓存分块与寄存器分块结合的综合优化；
6. 正确性验证、运行时间测量和实验数据收集。

所有函数计算：

```text
C = C + A * B
```

`A`、`B`、`C` 均为 `n × n` 的 `double` 方阵，使用一维数组按行优先存储：

```c
A[i][j]  <=>  A[i * n + j]
```

本实验在一个 Linux 环境中完成。

## 2. 需要提交的内容

请通过Canvas提交以下内容：

提交：

1. 完成后的 `src/mygemm.c`；
2. 一份PDF实验报告，包含本说明第 9 节要求的表格和图；


## 3. Linux 环境准备

### 3.1 安装编译工具

需要：

- 64 位 Linux；
- GCC 或 Clang；
- CMake 3.16 或更高版本；
- Make 或 Ninja；
- Git；
- 建议至少 8 GiB 内存。

Ubuntu/Debian 可运行：

```bash
sudo apt update
sudo apt install build-essential cmake git
```

### 3.2 不需要安装 BLAS

框架已经内置本实验所需的跨平台 `cblas_dgemm` 参考实现。不需要安装 Intel MKL、OpenBLAS 或其他数学库，也不需要配置库路径。

配置 CMake 时应看到：

```text
Using bundled portable cblas_dgemm reference backend
```

如果构建过程仍引用 `/act/opt/intel/mkl`、`mkl_avx2` 或 Tardis，请确认使用的是当前框架，并在新的构建目录中重新配置。交我算上的 `sbatch` 是正常的作业提交命令。



## 4. 获取和检查框架


框架中的主要文件：

| 文件                           | 作用                       | 是否需要修改 |
| ------------------------------ | -------------------------- | ------------ |
| `src/mygemm.c`                 | 学生实现所有矩阵乘法函数   | 是           |
| `include/mygemm.h`             | 函数接口                   | 否           |
| `benchmarks/reg_reuse.c`       | 寄存器复用测试程序         | 否           |
| `benchmarks/cache_part3.c`     | 循环次序与缓存分块测试程序 | 否           |
| `benchmarks/cache_part4.c`     | 综合优化测试程序           | 否           |
| `src/util.c`、`include/util.h` | 初始化、计时和正确性检查   | 否           |
| `third_party/labblas/`         | 内置参考 BLAS              | 否           |

评分时只考虑你的 `src/mygemm.c`，因此不要依赖对其他源文件的修改。

## 5. 编译框架

以下手动命令在 Linux 环境运行；使用交我算时，先进入 Slurm 分配的计算节点，再进入本仓库根目录（路径按实际位置替换）：

```bash
cd ~/SJTU-CS2315-lab2
cmake -S . -B build
cmake --build build -j1
(cd build && ctest --output-on-failure)
```

`ctest` 应显示两个测试通过：

```text
bundled_blas_reference
framework_correctness_pipeline
```

这两个测试只检查框架和参考 BLAS，不检查尚未实现的 `src/mygemm.c`。

如果修改 `src/mygemm.c` 后需要重新编译，只需运行：

```bash
cmake --build build -j1
```

建议先保留编译器警告。不得通过删除正确性检查或修改测试程序来消除错误。

## 6. 编程任务

所有函数都在 `src/mygemm.c` 中实现。不得修改函数名称、参数或返回类型。

实现中不得调用 MKL、OpenBLAS、BLAS、Eigen 或其他现成矩阵乘法函数。框架中的 `cblas_dgemm` 只用于生成参考答案，不计入实验结果中的运行时间。

### 6.1 `dgemm0`：基础三重循环

实现最直接的 `ijk` 三重循环版本：

```c
void dgemm0(const double *A, const double *B, double *C, int n);
```

要求：

- 每次内层循环直接更新 `C[i*n+j]`；
- 结果必须是 `C = C + A * B`；
- 不允许假设 `C` 初始为零。

### 6.2 `dgemm1`：单元素寄存器复用

```c
void dgemm1(const double *A, const double *B, double *C, int n);
```

要求：

- 在局部 `double` 变量中保存 `C[i*n+j]`；
- 完成整个 `k` 循环后再写回 `C`；
- 与 `dgemm0` 使用相同的计算语义。

### 6.3 `dgemm2`：2×2 寄存器分块

```c
void dgemm2(const double *A, const double *B, double *C, int n);
```

要求：

- 每次处理一个 2×2 的 `C` 子块；
- 使用 4 个局部累加变量保存该子块；
- 在内层循环中复用读取的 `A` 和 `B` 元素；
- 内层循环完成后再写回 4 个结果。

正式测试规模n均为偶数。推荐额外处理奇数规模的边界，但不要为了处理边界破坏偶数规模下的性能。

### 6.4 `dgemm3`：更积极的寄存器分块

```c
void dgemm3(const double *A, const double *B, double *C, int n);
```

实现一个比 `dgemm2` 更积极的寄存器分块方案，要求：

- 最多使用16个局部累加变量；
- 尽量复用加载到局部变量中的 `A` 和 `B` 元素；
- 不得把结果临时写回全局矩阵后再读取；
- 必须通过框架正确性检查。

正式测试规模 `n` 必须能被 6 整除，具体取值见第 8.3 节。

### 6.5 六种循环次序

实现以下六个非分块的矩阵乘法函数：

```c
void ijk(const double *A, const double *B, double *C, int n);
void jik(const double *A, const double *B, double *C, int n);
void kij(const double *A, const double *B, double *C, int n);
void ikj(const double *A, const double *B, double *C, int n);
void jki(const double *A, const double *B, double *C, int n);
void kji(const double *A, const double *B, double *C, int n);
```

函数名表示从外层到内层的循环次序。例如 `ikj` 的循环顺序必须是 `i → k → j`。

可以使用局部标量保存重复使用的 `A`、`B` 或 `C` 元素，但不能改变循环次序。

### 6.6 六种缓存分块实现

实现：

```c
void bijk(const double *A, const double *B, double *C, int n, int b);
void bjik(const double *A, const double *B, double *C, int n, int b);
void bkij(const double *A, const double *B, double *C, int n, int b);
void bikj(const double *A, const double *B, double *C, int n, int b);
void bjki(const double *A, const double *B, double *C, int n, int b);
void bkji(const double *A, const double *B, double *C, int n, int b);
```

要求：

- `b` 是缓存块大小；
- 外层三个块循环的次序必须与函数名一致；
- 块内三个循环也采用对应次序；
- 可以假设n可以被b整除；

### 6.7 `optimal`：综合优化

综合你学到的知识和技术，实现一个最优化的矩阵乘法代码

```c
void optimal(const double *A,
             const double *B,
             double *C,
             int n,
             int b);
```

要求：

- 同时使用缓存分块和寄存器分块；
- `b` 控制缓存块大小；
- 可以在缓存块内部使用固定大小的寄存器微内核；
- 必须保持 `C = C + A * B`；
- 同一份代码需要在 `-O0`、`-O1`、`-O2`、`-O3` 下编译运行。

框架会生成：

```text
cache_part4_o0
cache_part4_o1
cache_part4_o2
cache_part4_o3
```

## 7. 调试和正确性测试

### 7.1 空白框架的预期行为

刚下载时 `src/mygemm.c` 中的函数为空。测试程序会输出 `INVALID` 并以非零状态退出，这是正常现象。

只有看到某个函数输出时间和 GFLOP/s，而不是 `INVALID`，该函数才算通过正确性检查。

### 7.2 小规模快速测试

每完成一个阶段后重新编译，并使用小矩阵测试：

```bash
cmake --build build -j1

./build/reg_reuse 6 12 24 48
./build/cache_part3 48 6
./build/cache_part4_o0 48 6
./build/cache_part4_o1 48 6
./build/cache_part4_o2 48 6
./build/cache_part4_o3 48 6
```

参数含义：

```text
reg_reuse [n1 n2 n3 ...]
cache_part3 [n] [block_size]
cache_part4_o* [n] [block_size]
```

`n_i` 为依次测试不同的矩阵尺寸，`block_size` 为缓存块尺寸。

### 7.3 推荐调试顺序

1. 完成并测试 `dgemm0`；
2. 完成 `dgemm1`～`dgemm3`；
3. 完成六种非分块循环次序；
4. 先完成一个分块函数，再按相同结构完成其余五个；
5. 最后实现 `optimal`；
6. 所有小规模测试通过后再运行正式规模。

常见错误：

- 把 `C = C + A * B` 写成 `C = A * B`；
- 每次进入函数时把 `C` 清零；
- 数组下标中的行跨度不是 `n`；
- 分块循环的上界写错；
- 块大小不能整除 `n` 时访问越界；
- 寄存器分块只写回部分结果；
- 为追求速度跳过某些乘加运算。

## 8. 正式运行与数据收集

### 8.1 建立结果目录

> 目的：建立统一的结果保存目录，便于后续整理实验数据和撰写报告。

```bash
mkdir -p results
```

以下命令使用 `tee`，结果既显示在终端，也保存到文件。`2>&1` 会把正确性错误一起写入日志。

### 8.2 在交我算使用 Slurm

如果在交我算运行实验，推荐使用Slurm脚本在向计算节点提交任务。

仓库的 [`slurm/`](slurm/README.md) 已提供 7 份基础实验脚本，覆盖第 7.2 节的小规模检查和第 8.3～8.7 节的正式实验。Bonus 另提供 1 份脚本，使用方法见第 10 节。
每份脚本在计算节点编译并运行，默认申请 CPU 队列的 **1 个节点、1 个进程、1 个 CPU 核心、3 小时**（`03:00:00`）。

保存源码后，在登录节点进入本仓库根目录（包含 `CMakeLists.txt`、`src/` 和 `slurm/`），例如：

```bash
cd ~/SJTU-CS2315-lab2
mkdir -p results
sbatch slurm/lab2-7.2.slurm
```

若仓库位于其他目录，请替换第一行路径。脚本通过 `SLURM_SUBMIT_DIR` 定位源码，必须从仓库根目录提交；不要进入 `slurm/` 后提交，也不要在登录节点用 `bash` 直接运行脚本。
Slurm 会在脚本启动前打开日志文件，因此必须先创建根目录的 `results/`。

各实验的提交命令、块大小参数、CMake 模块设置和日志查看方法见 [Slurm 使用说明](slurm/README.md)。
同一份仓库一次只运行一个作业，避免共享 `build/` 和 `results/` 时互相覆盖；正式实验前先通过小规模检查。

以下给出了在Slurm任务之外执行实验的具体命令，可以在任意Linux环境中使用。

### 8.3 寄存器复用实验

> 实验目的：比较基础矩阵乘法、单元素复用和寄存器分块，观察数据复用对运行性能的影响。

统一测试规模如下，均能被 6 整除，与 `reg_reuse` 的默认规模一致：

```text
66, 126, 258, 510, 1026, 2046
```

运行：

```bash
./build/reg_reuse 66 126 258 510 1026 2046 \
  2>&1 | tee results/register_reuse.txt
```

收集 `dgemm0`、`dgemm1`、`dgemm2`、`dgemm3` 在每个规模下的：

- 正确性状态；
- 执行时间（秒）；
- GFLOP/s。

### 8.4 循环次序实验

> 实验目的：比较六种循环次序，理解矩阵访问顺序对缓存局部性和运行性能的影响。

循环次序实验使用 `n=2048`。此处的 `b` 只供同一测试程序中的分块函数使用，先固定为 64：

```bash
./build/cache_part3 2048 64 \
  2>&1 | tee results/loop_orders.txt
```

从输出中收集六种非分块函数的时间和 GFLOP/s：

```text
ijk, jik, kij, ikj, jki, kji
```

### 8.5 缓存块大小实验

> 实验目的：比较不同缓存块大小，选出适合当前机器和矩阵规模的分块参数。

先使用 `n=1024` 筛选块大小，依次测试：

```text
b = 16, 32, 64, 128, 256
```

这些块大小都能整除 1024 和 2048。

```bash
: > results/cache_block_sweep.txt

for b in 16 32 64 128 256; do
  echo "===== block_size=${b} =====" | tee -a results/cache_block_sweep.txt
  ./build/cache_part3 1024 "$b" \
    2>&1 | tee -a results/cache_block_sweep.txt
done
```

每次运行都会同时输出非分块和分块算法。非分块算法与 `b` 无关，只需记录第一次的非分块结果；对每个 `b` 记录六种分块算法：

```text
bijk, bjik, bkij, bikj, bjki, bkji
```

根据 `n=1024` 的结果选出表现最好的两个候选块大小，然后在 `n=2048` 上确认。例如候选值为 64 和 128 时：

```bash
: > results/cache_block_2048.txt

for b in 64 128; do
  echo "===== n=2048, block_size=${b} =====" \
    | tee -a results/cache_block_2048.txt
  ./build/cache_part3 2048 "$b" \
    2>&1 | tee -a results/cache_block_2048.txt
done
```

把示例中的 64 和 128 替换为你在 1024 规模下选出的实际候选值。最终为 `optimal` 选择在 2048 规模下表现更好的块大小。

`cache_part3` 每次都会同时运行六种非分块算法和六种分块算法，因此 2048 规模可能运行较长时间。开始测试后应等待程序正常结束，不要仅因某个循环次序较慢就中断。

### 8.6 编译优化级别实验

> 实验目的：对同一份综合优化代码比较 `-O0`～`-O3`，观察编译器优化级别对性能的影响。

假设缓存分块实验中选出的块大小为 `64`，在最大规模 `n=2048` 上运行：

```bash
for opt in 0 1 2 3; do
  ./build/cache_part4_o${opt} 2048 64 \
    2>&1 | tee "results/optimal_O${opt}.txt"
done
```

如果最佳块大小不是 64，请把命令中的 64 替换为实际值。四个优化级别必须使用相同的 `n=2048` 和相同的 `b`。

### 8.7 重复运行

> 目的：在相同配置下重复测量并取中位数，检查性能稳定性并降低偶然波动对结论的影响。

正式结果建议重复 3 次并取中位数。示例：

```bash
: > results/optimal_O3_repeated.txt

for run in 1 2 3; do
  echo "===== run=${run} =====" | tee -a results/optimal_O3_repeated.txt
  ./build/cache_part4_o3 2048 64 \
    2>&1 | tee -a results/optimal_O3_repeated.txt
done
```

如果最佳块大小不是 64，请同样替换这里的块大小。

重复运行期间不要改变源代码、编译选项、矩阵规模或块大小。尽量关闭占用 CPU 的其他程序。

## 9. 实验数据整理

### 9.1 必须记录运行环境

请说明你的实验环境。如果不是在交我算上进行的实验，请具体说明所使用的CPU型号、内存型号、以及编译器版本。

### 9.2 表格 1：寄存器复用

|    n | dgemm0 GFLOP/s | dgemm1 GFLOP/s | dgemm2 GFLOP/s | dgemm3 GFLOP/s |
| ---: | -------------: | -------------: | -------------: | -------------: |
|   66 |                |                |                |                |
|  126 |                |                |                |                |
|  258 |                |                |                |                |
|  510 |                |                |                |                |
| 1026 |                |                |                |                |
| 2046 |                |                |                |                |

### 9.3 表格 2：六种循环次序

| 算法 | 时间/s | GFLOP/s | 正确性 |
| ---- | -----: | ------: | ------ |
| ijk  |        |         |        |
| jik  |        |         |        |
| kij  |        |         |        |
| ikj  |        |         |        |
| jki  |        |         |        |
| kji  |        |         |        |

### 9.4 表格 3：缓存块大小

至少为每个分块函数记录不同 `b` 下的 GFLOP/s。也可以为每个函数分别绘图。

|    b | bijk | bjik | bkij | bikj | bjki | bkji |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
|   16 |      |      |      |      |      |      |
|   32 |      |      |      |      |      |      |
|   64 |      |      |      |      |      |      |
|  128 |      |      |      |      |      |      |
|  256 |      |      |      |      |      |      |

在表格下另列两个候选块在 `n=2048` 下的确认结果。

### 9.5 表格 4：综合优化

| 优化级别 |    n |    b | 时间/s | GFLOP/s | 正确性 |
| -------- | ---: | ---: | -----: | ------: | ------ |
| -O0      | 2048 |      |        |         |        |
| -O1      | 2048 |      |        |         |        |
| -O2      | 2048 |      |        |         |        |
| -O3      | 2048 |      |        |         |        |

### 9.6 必须绘制的图

1. `dgemm0`～`dgemm3` 的 GFLOP/s 随 `n` 变化曲线；
2. 六种循环次序的 GFLOP/s 对比图；
3. 分块算法的 GFLOP/s 随块大小变化图；
4. `optimal` 在 `-O0`～`-O3` 下的 GFLOP/s 对比图。

图中必须标明标题、横轴、纵轴、单位、矩阵规模和块大小。

## 10. 奖励题目：进一步优化自己的矩阵乘法

完成基础实验后，可查阅资料并使用 AI 辅助进一步开展单线程矩阵乘法优化。重点是提出优化假设、理解并检查代码、通过实验验证效果，而不是仅让 AI 生成一份代码。无需额外下载库源码，也不要求一定达到或超过高性能 BLAS；有依据地解释性能差距、无效尝试和适用范围，同样是有价值的结果。

本题只研究 **CPU 单线程、双精度矩阵乘法**，不使用多线程或 GPU。SIMD 向量化属于单线程优化，可以使用。允许新增辅助函数、打包缓冲区、SIMD 内核和独立测试程序；第 6 节的基础任务要求仍按原规定执行，自己的矩阵乘法实现仍不得调用现成 GEMM。

建议从以下方向选择两项或更多开展实验，不必全部实现：

1. **多级缓存分块**：将单一块大小扩展为分别控制 `m`、`n`、`k` 方向的块大小，考虑 L1/L2/L3 缓存容量和数据复用；避免仅凭“块越大越好”选择参数。
2. **数据打包（packing）**：把 A、B 的子块整理为微内核便于连续访问的布局，减少跨行访问和地址计算。比较打包带来的收益与额外复制成本，观察小矩阵是否反而变慢。
3. **寄存器微内核与 SIMD/FMA**：设计不同形状的寄存器块，使用编译器自动向量化或当前 CPU 支持的向量指令；分析数据加载、累加依赖和寄存器不足导致的溢出到内存。
4. **编译器与生成代码分析**：查看向量化报告和关键循环的汇编，检查预期的向量化是否发生。可在独立的 Bonus 构建中试验 `-O3`、`-march=native` 等选项，记录完整参数；使用机器相关选项时，说明代码适用的 CPU。
5. **按规模选择实现**：为小矩阵采用较轻量的路径，为大矩阵采用打包与分块；测试不同微内核和分块参数，并处理不能整除块大小的边界。

可以先阅读 [Goto/BLIS 矩阵乘法教学材料](https://www.cs.utexas.edu/~flame/laff/pfhp/week3-goto.html)，理解多级分块、微面板打包和微内核之间的关系。使用 GCC 时，可参考 [优化诊断选项说明](https://gcc.gnu.org/onlinedocs/gcc/Developer-Options.html)，通过 `-fopt-info-vec-optimized`、`-fopt-info-vec-missed` 检查向量化成功或失败的原因。

**BLAS 对比对象与结论范围：**

- 默认对比仓库自带的 `labblas`，无需安装任何库。它只是教学参考后端，超过它不能直接说明已经逼近 OpenBLAS、BLIS 或 MKL 等高性能库。
- 若实验机器已经安装兼容的 OpenBLAS/CBLAS，可在另一个构建目录中启用 `-DLAB_USE_SYSTEM_BLAS=ON`，进一步探索与高性能库的差距。这个选项只链接已经安装的库，不会下载库；找不到时使用默认后端即可，不要求另行安装。
- 使用外部库时，记录库名称、版本和线程配置，并通过该库的线程设置确认实际只使用一个线程。只申请一个 CPU 核心不能替代库的线程设置。

对每个规模报告 `自己的 GFLOP/s / BLAS 的 GFLOP/s`，分析在哪些规模下接近、落后或超过对照，避免只展示最有利的一组数据。

### 10.1 在哪里写代码

基础实验仍在 `src/mygemm.c` 中完成；**进一步优化的代码写在 [`bonus/bonus_gemm.c`](bonus/bonus_gemm.c) 的 `bonus_gemm` 函数中**：

```c
void bonus_gemm(const double *a, const double *b_matrix, double *c,
                int n, int block_size);
```

矩阵仍为按行优先存储的 `n × n` 的 `double` 方阵，计算 `C = C + A * B`。`block_size` 是调优参数，允许在函数内部使用多级分块；必须处理任意正整数尺寸，包括奇数、不能整除块大小的尾块和 `block_size > n`。可在本文件新增辅助函数，不要修改接口或调用现成 GEMM。

| 文件 | 学生需要做什么 |
| --- | --- |
| [`bonus/baseline_gemm.c`](bonus/baseline_gemm.c) | 将基础实验中最好的实现复制到 `baseline_gemm`，补齐边界后冻结为对照。已有可运行的 `ikj` 示例，但它不代表你的基础实验最佳实现。 |
| [`bonus/bonus_gemm.c`](bonus/bonus_gemm.c) | 先复制对照版本的代码，再在这里进行进一步优化。 |
| [`bonus/gemm.h`](bonus/gemm.h) | 查看接口和输入约定，无需修改。 |
| [`bonus/benchmark.c`](bonus/benchmark.c) | 已提供正确性检查和性能对比程序，通常无需修改。 |
| [`bonus/run.sh`](bonus/run.sh) | Linux 下的一键编译、检查和测量脚本。 |
| [`slurm/lab2-10-bonus.slurm`](slurm/lab2-10-bonus.slurm) | 交我算的单核心任务提交脚本。 |

`bonus_gemm` 模板初始为空，运行会显示 `INVALID` 并以非零状态退出，这是正常行为。完成代码后，它会与冻结的 `baseline_gemm` 和未修改的 BLAS 同时接受检查。不要修改 `third_party/labblas/` 来改变对照结果或绕过检查。

### 10.2 本地编译与测试（Linux）

以下命令都从仓库根目录执行，只构建 Bonus 目标，不依赖基础实验函数是否已实现：

```bash
cmake -S . -B build-bonus -DLAB_BUILD_BONUS=ON -DLAB_USE_SYSTEM_BLAS=OFF
cmake --build build-bonus --target bonus_gemm -j1

# 先检查正确性：180 组小规模、块大小和输入模式组合。
./build-bonus/bonus/bonus_gemm --check

# 再测性能：n=512，块大小64，预热后测5次。
./build-bonus/bonus/bonus_gemm 512 64 5
```

性能测试分别输出 `baseline`、`bonus` 和 `BLAS` 的耗时中位数、GFLOP/s、最大绝对误差，以及 `speedup_vs_baseline`（基础版本耗时 / Bonus 耗时）和 `bonus_over_BLAS`（Bonus 的 GFLOP/s / BLAS 的 GFLOP/s）。

也可用一键脚本完成编译、正确性检查和小/中/大规模对比：

```bash
# 默认 b=64，重复5次，测试 n=128、512、1024、2048。
bash bonus/run.sh

# 自定义：b=32，重复7次，测试 n=128、512、1024。
bash bonus/run.sh 32 7 128 512 1024
```

日志保存到 `results/bonus-local-时间-进程号/`，包含环境信息、实际构建命令、CMake 配置、正确性结果、每次测量和汇总结果。

Bonus 默认以 `-O3` 编译。

### 10.3 在交我算提交 Bonus 任务

保存 `bonus/baseline_gemm.c` 和 `bonus/bonus_gemm.c` 后，在登录节点进入仓库根目录提交，不要在登录节点直接运行一键测试脚本：

```bash
cd ~/SJTU-CS2315-lab2
mkdir -p results
sbatch slurm/lab2-10-bonus.slurm

# 或传入 b、重复次数和矩阵尺寸：
sbatch slurm/lab2-10-bonus.slurm 32 7 128 512 1024
```

脚本默认申请 CPU 队列的 1 个节点、1 个进程、1 个 CPU 核心、3 小时，在计算节点编译，通过小规模检查后才开始性能测量。测量通过 `srun --cpu-bind=cores` 运行。默认参数与本地一键脚本相同，结果保存到 `results/bonus-作业编号/`，任务总日志为 `results/lab2-bonus-作业编号.log`。空模板或错误代码会使任务失败，不会继续输出性能结果。

如果平台的 CMake 模块名不是 `cmake`，按 [Slurm 使用说明](slurm/README.md) 设置 `CMAKE_MODULE`。如需本机指令集或已安装的系统 BLAS，可在提交前分别 `export BONUS_NATIVE=ON` 或 `export BONUS_SYSTEM_BLAS=ON`；系统库所需模块也应提前加载并确认能在计算节点使用。不要上传本地的 `build-bonus/`。

### 10.4 Bonus 提交内容

除基础作业外，提交 `bonus/` 中的代码及新增辅助文件，在 PDF 报告末尾附上 Bonus 的优化思路、正确性结果和小/中/大规模性能对比。说明 AI 工具、关键提示词以及你如何检查和修正其建议。
