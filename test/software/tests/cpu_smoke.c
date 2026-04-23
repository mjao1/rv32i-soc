__attribute__((noinline)) static int max3(int a, int b, int c) {
  int m = a;
  if (b > m)
    m = b;
  if (c > m)
    m = c;
  return m;
}

__attribute__((noinline)) static int sum_range(int lo, int hi) {
  int s = 0;
  int i;
  for (i = lo; i <= hi; i = i + 1)
    s = s + i;
  return s;
}

int main(void) {
  volatile int lo = 1;
  volatile int hi = 100;
  volatile int a = 12;
  volatile int b = 44;
  volatile int c = 33;
  return sum_range(lo, hi) + max3(a, b, c);
  /* Result: sum_range(1,100) + max3(12,44,33) == 5050 + 44 == 5094 */
}
