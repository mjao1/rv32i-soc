/* Same numeric result as cpu_smoke.c, but globals in .data (fewer stack spills) for AXI LSU paths. */
static int max3(int a, int b, int c) {
  int m = a;
  if (b > m)
    m = b;
  if (c > m)
    m = c;
  return m;
}

static int sum_range(int lo, int hi) {
  int s = 0;
  int i;
  for (i = lo; i <= hi; i = i + 1)
    s = s + i;
  return s;
}

int main(void) {
  return sum_range(1, 100) + max3(12, 44, 33);
}
