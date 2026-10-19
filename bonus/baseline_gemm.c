#include "gemm.h"

#include <stddef.h>

/* 对照版本：先把基础实验中最好的实现复制到这里，之后保持不变。
 * 可以新增 static 辅助函数，但不要调用 bonus_gemm 或 BLAS。
 * 下面的 ikj 示例只用于让测试框架可以运行，不代表你的基础实验成绩。
 * 如果原代码只支持整除尺寸，请补齐边界后再作为 Bonus 的对照。 */
void baseline_gemm(const double *a, const double *b_matrix, double *c,
                   int n, int block_size)
{
    int i, j, k;
    (void)block_size;

    for (i = 0; i < n; ++i) {
        for (k = 0; k < n; ++k) {
            const double aik = a[(size_t)i * n + k];
            for (j = 0; j < n; ++j) {
                c[(size_t)i * n + j] += aik * b_matrix[(size_t)k * n + j];
            }
        }
    }
}
