/* SoC integration test: exercises DMEM, GPIO, TIMER, and UART.
 * Each sub-test returns 1 on pass, 0 on fail. `main` packs the per-module
 * result into bits 0..3 of a0 (x10) so the simulation testbench can check
 * against 0xF for a clean pass. UART sub-test assumes TX is looped back to
 * RX at the testbench level. */
#define GPIO_BASE 0x10000000u
#define UART_BASE 0x10001000u
#define TIMER_BASE 0x10002000u

#define REG32(a) (*(volatile unsigned int *)(a))

#define GPIO_DATA REG32(GPIO_BASE + 0x0)
#define GPIO_DIR REG32(GPIO_BASE + 0x4)

#define UART_DATA REG32(UART_BASE + 0x0)
#define UART_STAT REG32(UART_BASE + 0x4)
#define UART_DIV REG32(UART_BASE + 0x8)

#define UART_RXNE (1u << 0)
#define UART_TXE (1u << 1)
#define UART_BUSY (1u << 2)

#define TIMER_COUNT REG32(TIMER_BASE + 0x0)
#define TIMER_RELOAD REG32(TIMER_BASE + 0x4)
#define TIMER_CTRL REG32(TIMER_BASE + 0x8)

#define TIMEOUT_SPINS 200000

static int test_dmem(void) {
  volatile unsigned int buf[8];
  volatile unsigned char *b = (volatile unsigned char *)buf;
  volatile unsigned short *h = (volatile unsigned short *)buf;
  unsigned int i;

  for (i = 0; i < 8; i++) buf[i] = 0xA5A50000u + i;
  for (i = 0; i < 8; i++) if (buf[i] != 0xA5A50000u + i) return 0;

  b[0] = 0xDE; b[1] = 0xAD; b[2] = 0xBE; b[3] = 0xEF;
  if (buf[0] != 0xEFBEADDEu) return 0;

  h[2] = 0x1234; h[3] = 0x5678;
  if (buf[1] != 0x56781234u) return 0;

  buf[2] = 0xFF80807Fu;
  if ((signed char)b[8]  != 0x7F) return 0;
  if ((signed char)b[11] != (signed char)0xFF) return 0;
  if ((unsigned char)b[11] != 0xFFu) return 0;

  return 1;
}

static int test_gpio(void) {
  GPIO_DIR = 0xFFFFFFFFu;
  if (GPIO_DIR != 0xFFFFFFFFu) return 0;
  GPIO_DATA = 0xDEADBEEFu;
  if (GPIO_DATA != 0xDEADBEEFu) return 0;
  GPIO_DATA = 0xA5A5A5A5u;
  if (GPIO_DATA != 0xA5A5A5A5u) return 0;
  GPIO_DIR = 0x0000FFFFu;
  GPIO_DATA = 0xFFFFFFFFu;
  if (GPIO_DATA != 0x0000FFFFu) return 0;
  return 1;
}

static int test_timer(void) {
  TIMER_CTRL = 0;
  TIMER_RELOAD = 0xCAFECAFEu;
  if (TIMER_RELOAD != 0xCAFECAFEu) return 0;

  unsigned int c_pre_a = TIMER_COUNT;
  unsigned int c_pre_b = TIMER_COUNT;
  if (c_pre_a != c_pre_b) return 0;

  TIMER_CTRL = 1;
  if ((TIMER_CTRL & 1u) != 1u) return 0;

  unsigned int c1 = TIMER_COUNT;
  for (volatile int j = 0; j < 20; j++) { (void)j; }
  unsigned int c2 = TIMER_COUNT;

  TIMER_CTRL = 0;
  if (!(c2 > c1)) return 0;

  unsigned int c3 = TIMER_COUNT;
  unsigned int c4 = TIMER_COUNT;
  if (c3 != c4) return 0;

  return 1;
}

static int test_uart(void) {
  UART_DIV = 8;
  if (UART_DIV != 8) return 0;

  unsigned int s0 = UART_STAT;
  if (!(s0 & UART_TXE)) return 0;
  if (s0 & UART_BUSY) return 0;
  if (s0 & UART_RXNE) return 0;

  UART_DATA = 'H';

  int spin = 0;
  while (1) {
    unsigned int s = UART_STAT;
    if ((s & UART_TXE) && !(s & UART_BUSY)) break;
    if (++spin > TIMEOUT_SPINS) return 0;
  }

  spin = 0;
  while (!(UART_STAT & UART_RXNE)) {
    if (++spin > TIMEOUT_SPINS) return 0;
  }

  unsigned int rx = UART_DATA & 0xFFu;
  if (rx != 'H') return 0;
  if (UART_STAT & UART_RXNE) return 0;

  return 1;
}

int main(void) {
  int score = 0;
  if (test_dmem())  score |= (1 << 0);
  if (test_gpio())  score |= (1 << 1);
  if (test_timer()) score |= (1 << 2);
  if (test_uart())  score |= (1 << 3);
  return score;
}
