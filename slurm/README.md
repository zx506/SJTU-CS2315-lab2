# 交我算 Slurm 实验脚本

本目录包含 8 份适用于当前独立 Lab 2 仓库的脚本。默认申请 CPU 队列的 **1 个节点、1 个进程、1 个 CPU 核心、3 小时**（`03:00:00`）。计时从资源分配后开始，包括编译、检查和实验运行，不含排队时间。

## 提交前

1. 保存 `src/mygemm.c`。完成所测函数后先运行第 7.2 节的小规模检查，通过后再提交正式实验。
2. 回到交我算的登录节点，在仓库根目录执行：

```bash
cd ~/SJTU-CS2315-lab2
mkdir -p results
```

若仓库位于其他目录，请替换上面的路径；根目录应包含 `CMakeLists.txt` 和 `src/`。下面每次选择一条命令提交。脚本通过 `SLURM_SUBMIT_DIR` 定位源码，必须从仓库根目录运行 `sbatch`。Slurm 在执行脚本前打开日志文件，因此根目录的 `results/` 必须提前存在。

## 实验与提交命令

文件名中的编号对应本仓库 README 的小节。一个小节有多份实验脚本时，加上实验内容后缀；例如 8.5 的 `block-sweep` 表示初筛，`block-confirm` 表示候选确认。

| README 小节 | 实验 | 在仓库根目录提交 | 实验参数或用途 |
| --- | --- | --- | --- |
| Lab2 §7.2 | Lab 2 快速检查 | `sbatch slurm/lab2-7.2.slurm` | 寄存器 `6 12 24 48`，缓存及综合优化 `48 6` |
| Lab2 §8.3 | 寄存器复用 | `sbatch slurm/lab2-8.3.slurm` | `66 126 258 510 1026 2046`，均能被 6 整除 |
| Lab2 §8.4 | 循环次序 | `sbatch slurm/lab2-8.4.slurm` | `n=2048`、`b=64`，同时运行六个分块函数 |
| Lab2 §8.5 | 缓存块大小筛选 | `sbatch slurm/lab2-8.5-block-sweep.slurm` | `n=1024`，`b=16、32、64、128、256` |
| Lab2 §8.5 | 候选块大小确认 | `sbatch slurm/lab2-8.5-block-confirm.slurm 64 128` | `n=2048`，传入两个实际候选值 |
| Lab2 §8.6 | 编译优化级别比较 | `sbatch slurm/lab2-8.6.slurm 64` | `n=2048`，O0～O3 使用同一个实际最佳 `b` |
| Lab2 §8.7 | O3 重复测量 | `sbatch slurm/lab2-8.7.slurm 64` | `n=2048`，按实际最佳 `b` 重复三次 |
| Lab2 §10 | Bonus 进一步优化 | `sbatch slurm/lab2-10-bonus.slurm 64 5 128 512 1024 2048` | `b`、重复次数、矩阵尺寸列表；省略参数使用表中默认值 |

表格中的 `64 128` 和最佳 `b=64` 都是示例。请按上一阶段的测量结果替换。候选确认脚本要求两个不同的候选值；三个需要块大小参数的脚本均从 `16、32、64、128、256` 中选择，缺少或传错参数会退出。

正式数据要求见 [Lab 2 README 第 8、9 节](../README.md)。

Bonus 在 `bonus/bonus_gemm.c` 编写代码，使用独立的 `build-bonus/` 构建目录和 `results/bonus-作业编号/` 结果目录。它只构建 Bonus 目标，运行自己的 180 组正确性检查后比较基础版本、进一步优化版本和 BLAS，不执行基础实验的两个框架自检。具体步骤见 [第 10 节](../README.md#10-奖励题目进一步优化自己的矩阵乘法)。下文关于共享 `build/` 和固定结果文件的说明适用于基础实验；Bonus 也应避免在同一源码目录同时构建或修改代码。

## 运行顺序与结果保存

- **同一份 Lab 2 目录一次只运行一个作业。** 脚本共享 `build/` 和 `results/`。等上一作业结束后再修改源码、编译或提交下一阶段。
- 基础实验的 7 份脚本都会加载 CMake、单线程构建、运行两个框架自检，再执行对应实验。使用 `(cd build && ctest --output-on-failure)`，兼容 CMake/CTest 3.16 及以上版本。Bonus 的检查步骤见上文。
- 空白学生模板出现 `INVALID` 或非零退出码属于预期情况。框架自检通过并不代表学生实现正确。
- 实验通过 `srun --cpu-bind=cores` 运行。`set -euo pipefail` 保留程序失败状态，`tee` 不会把失败伪装成成功。
- 仓库根目录的 `results/` 同时保存带作业编号的总日志、README 规定名称的实验数据、快速检查结果和 `environment.txt`。环境信息也会打印到该作业的总日志。
- 重跑同一阶段会覆盖对应实验数据文件。重跑前先下载或另存上一批结果，再按要求取三次结果的中位数。

例如循环次序实验返回作业编号 `123456` 后：

```bash
squeue -u "$USER"
tail -F results/lab2-123456.log
# 按 Ctrl-C 结束日志查看，再执行下一条。
sacct -j 123456 --format=JobID,State,ExitCode,Elapsed
```

其他阶段日志以脚本的 `#SBATCH -o` 为准，例如 `results/lab2-register-123456.log`。只有状态为 `COMPLETED`、`ExitCode=0:0` 且正确性检查通过，才确认本次实验成功。3 小时是运行上限，不保证所有实现都能在时限内完成。

## CMake 模块

默认使用 `module load cmake`。若平台没有默认模块，在登录节点用 `module avail cmake` 查出实际模块名，并通过环境变量传入，例如将下面的占位符替换后提交：

```bash
export CMAKE_MODULE="实际存在的完整模块名"
sbatch slurm/lab2-7.2.slurm
```

该变量只影响当前终端提交的 Lab 2 作业。不要向交我算上传本地 `build/` 或 `CMakeCache.txt`。

参考：[交我算 Slurm 手册](https://docs.hpc.sjtu.edu.cn/job/slurm.html)、[Slurm sbatch 文档](https://slurm.schedmd.com/sbatch.html)、[Slurm srun 文档](https://slurm.schedmd.com/srun.html)。
