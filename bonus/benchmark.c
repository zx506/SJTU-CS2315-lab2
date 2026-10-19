#include "gemm.h"
#include "util.h"

#include <cblas.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_REPEATS 101

typedef void (*kernel)(const double *, const double *, double *, int, int);

static void blas_gemm(const double *a, const double *b, double *c,
                      int n, int block_size)
{
    (void)block_size;
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                n, n, n, 1.0, a, n, b, n, 1.0, c, n);
}

/* Independent oracle for the small correctness suite, never timed. */
static void naive_gemm(const double *a, const double *b, double *c, int n)
{
    int i, j, k;
    for (i = 0; i < n; ++i) {
        for (j = 0; j < n; ++j) {
            double sum = c[(size_t)i * n + j];
            for (k = 0; k < n; ++k) {
                sum += a[(size_t)i * n + k] * b[(size_t)k * n + j];
            }
            c[(size_t)i * n + j] = sum;
        }
    }
}

static int check_result(const double *actual, const double *expected, int n,
                         double *max_error)
{
    size_t i, count = (size_t)n * n;
    int valid = 1;
    for (i = 0; i < count; ++i) {
        double error = fabs(actual[i] - expected[i]);
        double tolerance = 1e-8 + 1e-10 * fmax(fabs(actual[i]), fabs(expected[i]));
        if (!isfinite(actual[i]) || !isfinite(expected[i])) {
            *max_error = INFINITY;
            valid = 0;
        } else {
            if (error > *max_error) *max_error = error;
            if (error > tolerance) valid = 0;
        }
    }
    return valid;
}

static int compare_double(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static double median(double *samples, int count)
{
    qsort(samples, (size_t)count, sizeof(*samples), compare_double);
    return count % 2 ? samples[count / 2]
                     : (samples[count / 2 - 1] + samples[count / 2]) / 2.0;
}

static int positive_int(const char *text, int *value)
{
    char *end;
    long parsed;
    errno = 0;
    parsed = strtol(text, &end, 10);
    if (errno || end == text || *end || parsed <= 0 || parsed > INT_MAX) return 0;
    *value = (int)parsed;
    return 1;
}

/* All three backends use the same inputs, initial C, and validation rule.
 * mode 0: random; mode 1: A = 0; mode 2: B = identity.
 * Small checks use the independent naive oracle; large runs use unmodified BLAS. */
static int run_case(int n, int block_size, int repeats, int mode, int timed)
{
    const char *names[] = {"baseline", "bonus", "BLAS"};
    kernel functions[] = {baseline_gemm, bonus_gemm, blas_gemm};
    double samples[3][MAX_REPEATS];
    double max_error[3] = {0.0, 0.0, 0.0};
    double times[3];
    double *a = allocate_matrix(n, n);
    double *b = allocate_matrix(n, n);
    double *initial = allocate_matrix(n, n);
    double *actual = allocate_matrix(n, n);
    double *expected = allocate_matrix(n, n);
    size_t i, count = (size_t)n * n;
    int run, slot, failed = 0;

    if (!a || !b || !initial || !actual || !expected) {
        fprintf(stderr, "Cannot allocate matrices for n=%d\n", n);
        failed = 1;
        goto cleanup;
    }
    seed_random(211U);
    randomize_matrix(a, n, n);
    randomize_matrix(b, n, n);
    randomize_matrix(initial, n, n);
    /* Guarantee a nonzero initial C even for n = 1. */
    initial[0] = 1.25;
    if (mode == 1) {
        for (i = 0; i < count; ++i) a[i] = 0.0;
    } else if (mode == 2) {
        for (i = 0; i < count; ++i) b[i] = 0.0;
        for (i = 0; i < (size_t)n; ++i) b[i * n + i] = 1.0;
    }
    matrix_copy(expected, initial, n, n);
    if (timed) blas_gemm(a, b, expected, n, block_size);
    else naive_gemm(a, b, expected, n);

    /* run = -1 is a checked warm-up, not a timing sample.
     * Rotate backend order to reduce systematic measurement-order bias. */
    for (run = -1; run < (timed ? repeats : 0); ++run) {
        for (slot = 0; slot < 3; ++slot) {
            int which = (slot + run + 1) % 3;
            double start, elapsed;
            matrix_copy(actual, initial, n, n); /* Restore C outside the timer. */
            start = get_sec();
            functions[which](a, b, actual, n, block_size);
            elapsed = get_sec() - start;
            if (!check_result(actual, expected, n, &max_error[which])) {
                fprintf(stderr, "INVALID: %s n=%d b=%d mode=%d run=%d max_abs_error=%.6e\n",
                        names[which], n, block_size, mode, run, max_error[which]);
                failed = 1;
                goto cleanup; /* Never publish performance for incorrect results. */
            }
            if (timed && run >= 0) {
                if (!(elapsed > 0.0) || !isfinite(elapsed)) {
                    fprintf(stderr, "Timer resolution insufficient; use a larger n.\n");
                    failed = 1;
                    goto cleanup;
                }
                samples[which][run] = elapsed;
            }
        }
        if (timed && run >= 0) {
            printf("sample n=%d b=%d run=%d baseline_s=%.9g bonus_s=%.9g blas_s=%.9g\n",
                   n, block_size, run + 1, samples[0][run], samples[1][run], samples[2][run]);
        }
    }
    if (timed) {
        for (slot = 0; slot < 3; ++slot) {
            times[slot] = median(samples[slot], repeats);
            printf("summary n=%d b=%d backend=%s median_s=%.9g GFLOP/s=%.6f max_abs_error=%.6e PASS\n",
                   n, block_size, names[slot], times[slot],
                   2.0 * n * n * n / (times[slot] * 1e9), max_error[slot]);
        }
        printf("comparison n=%d speedup_vs_baseline=%.6f bonus_over_BLAS=%.6f\n",
               n, times[0] / times[1], times[2] / times[1]);
    }
cleanup:
    free(a); free(b); free(initial); free(actual); free(expected);
    return failed;
}

int main(int argc, char **argv)
{
    int n = 512, block_size = 64, repeats = 5;
    if (argc == 2 && strcmp(argv[1], "--check") == 0) {
        const int sizes[] = {1, 2, 3, 5, 6, 7, 15, 16, 17, 31, 32, 33, 63, 64, 65};
        const int blocks[] = {1, 6, 16, 64};
        size_t i, j;
        int mode;
        for (i = 0; i < sizeof(sizes) / sizeof(sizes[0]); ++i) {
            for (j = 0; j < sizeof(blocks) / sizeof(blocks[0]); ++j) {
                for (mode = 0; mode < 3; ++mode) {
                    if (run_case(sizes[i], blocks[j], 1, mode, 0)) return EXIT_FAILURE;
                }
            }
        }
        puts("Correctness: 180 cases passed for baseline, bonus and BLAS (independent naive reference).");
        return EXIT_SUCCESS;
    }
    if (argc > 4 || (argc > 1 && !positive_int(argv[1], &n)) ||
        (argc > 2 && !positive_int(argv[2], &block_size)) ||
        (argc > 3 && !positive_int(argv[3], &repeats)) || repeats > MAX_REPEATS) {
        fprintf(stderr, "Usage: %s --check | [n [block_size [repeats (1..101)]]]\n", argv[0]);
        return EXIT_FAILURE;
    }
#ifdef LAB_BONUS_SYSTEM_BLAS
    puts("BLAS backend: installed system CBLAS (record its name/version and verify single-thread configuration).");
#else
    puts("BLAS backend: bundled teaching labblas (not a production BLAS performance target).");
#endif
    puts("Timing: one warm-up, fresh nonzero C per call, full GEMM call included, checks excluded.");
    printf("Configuration: n=%d b=%d repeats=%d\n", n, block_size, repeats);
    return run_case(n, block_size, repeats, 0, 1) ? EXIT_FAILURE : EXIT_SUCCESS;
}
