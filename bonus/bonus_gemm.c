#include "gemm.h"

/* 第 10 节 Bonus 的代码入口：在本文件实现进一步优化的矩阵乘法。
 * 起点：复制 baseline_gemm 的代码，然后逐步优化。
 * 语义：行优先 double 方阵，C = C + A * B，不能假设 C 初始为零。
 * 要求：单线程，不调用现成 GEMM；不修改函数接口。
 * 可以在本文件新增 static 辅助函数、打包缓冲区、SIMD 微内核等。
 * n、block_size 为任意正数，需要处理奇数、尾块以及 block_size > n。
 * 每次调用必需的分配、打包和释放应在函数内部，都会计入运行时间。
 * 当前函数为空，测试会显示 INVALID 并返回非零状态，这是预期行为。 */
void bonus_gemm(const double *a, const double *b_matrix, double *c,
                int n, int block_size)
{
    (void)a;
    (void)b_matrix;
    (void)c;
    (void)n;
    (void)block_size;
    /* TODO: 在这里写你的进一步优化版本。 */
}
