/* soc_program_1: walking 1 pattern + fixed values to GPIO. GPIO focused.
 * Verifies readback through the AXI-Lite GPIO slave. Returns magic word. */
#define GPIO_BASE 0x10000000u

#define REG32(a) (*(volatile unsigned int *)(a))

#define GPIO_DATA REG32(GPIO_BASE + 0x0)
#define GPIO_DIR  REG32(GPIO_BASE + 0x4)

int main(void) {
  GPIO_DIR = 0xFFFFFFFFu;
  if (GPIO_DIR != 0xFFFFFFFFu) return 0;

  unsigned int walk = 1u;
  for (int i = 0; i < 8; i++) {
    GPIO_DATA = walk;
    if (GPIO_DATA != walk) return 0;
    walk <<= 1;
  }

  GPIO_DATA = 0x55555555u;
  if (GPIO_DATA != 0x55555555u) return 0;

  GPIO_DATA = 0xAAAAAAAAu;
  if (GPIO_DATA != 0xAAAAAAAAu) return 0;

  return (int)0xCAFECAFE;
}
