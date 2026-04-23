/* soc_program_3: bubble-sort 8 ints in DMEM, write packed result to GPIO, and
 * return (min << 16) | (max & 0xFFFF). DMEM & compute focused (loads, stores,
 * branches, forwarding). Independent of UART / timer, no loopback required. */
#define GPIO_BASE 0x10000000u

#define REG32(a) (*(volatile unsigned int *)(a))

#define GPIO_DATA REG32(GPIO_BASE + 0x0)
#define GPIO_DIR  REG32(GPIO_BASE + 0x4)

int main(void) {
  volatile int a[8];
  a[0] = 42;
  a[1] = -3;
  a[2] = 17;
  a[3] = 8;
  a[4] = -99;
  a[5] = 256;
  a[6] = 0;
  a[7] = 7;

  int n = 8;
  for (int i = 0; i < n - 1; i++) {
    for (int j = 0; j < n - 1 - i; j++) {
      int x = a[j];
      int y = a[j + 1];
      if (x > y) {
        a[j] = y;
        a[j + 1] = x;
      }
    }
  }

  GPIO_DIR = 0xFFFFFFFFu;
  unsigned int packed = ((unsigned int)a[0] << 16) | ((unsigned int)a[7] & 0xFFFFu);
  GPIO_DATA = packed;
  if (GPIO_DATA != packed) return 0;

  /* Sorted: {-99,-3,0,7,8,17,42,256}; min=-99 (0xFFFFFF9D), max=256 (0x100)
   * packed = (0xFFFFFF9D << 16) | (0x100 & 0xFFFF) = 0xFF9D_0100 */
  return (int)packed;
}
