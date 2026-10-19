#ifndef LAB_BONUS_GEMM_H
#define LAB_BONUS_GEMM_H

/* Row-major n x n matrices. Both functions compute C += A * B.
 * A and B are read-only; C is not necessarily zero. b is a tuning parameter.
 * Support every positive n and b, including n % b != 0 and b > n. */
void baseline_gemm(const double *a, const double *b_matrix, double *c,
                   int n, int block_size);
void bonus_gemm(const double *a, const double *b_matrix, double *c,
                int n, int block_size);

#endif
