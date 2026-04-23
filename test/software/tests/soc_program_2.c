/* soc_program_2: send a short string over UART, loopback returns each byte,
 * XOR-checksum the received bytes, return checksum. UART focused.
 * Expects testbench to drive RX <- TX loopback (+LOOPBACK). */
#define UART_BASE 0x10001000u

#define REG32(a) (*(volatile unsigned int *)(a))

#define UART_DATA REG32(UART_BASE + 0x0)
#define UART_STAT REG32(UART_BASE + 0x4)
#define UART_DIV  REG32(UART_BASE + 0x8)

#define UART_RXNE (1u << 0)
#define UART_TXE  (1u << 1)
#define UART_BUSY (1u << 2)

#define TIMEOUT_SPINS 200000

static int uart_xchg(unsigned char tx, unsigned char *rx_out) {
  int spin = 0;
  while (!(UART_STAT & UART_TXE)) { if (++spin > TIMEOUT_SPINS) return 0; }
  UART_DATA = tx;

  spin = 0;
  while (1) {
    unsigned int s = UART_STAT;
    if ((s & UART_TXE) && !(s & UART_BUSY)) break;
    if (++spin > TIMEOUT_SPINS) return 0;
  }

  spin = 0;
  while (!(UART_STAT & UART_RXNE)) { if (++spin > TIMEOUT_SPINS) return 0; }
  *rx_out = (unsigned char)(UART_DATA & 0xFFu);
  return 1;
}

int main(void) {
  volatile unsigned char msg[5];
  msg[0] = 'r';
  msg[1] = 'v';
  msg[2] = '3';
  msg[3] = '2';
  msg[4] = 'i';

  UART_DIV = 8;
  if (UART_DIV != 8) return 0;

  unsigned int checksum = 0;
  for (int i = 0; i < 5; i++) {
    unsigned char rx;
    if (!uart_xchg(msg[i], &rx)) return 0;
    if (rx != msg[i]) return 0;
    checksum ^= rx;
  }

  /* XOR of "rv32i" = 0x72 ^ 0x76 ^ 0x33 ^ 0x32 ^ 0x69 = 0x6C */
  return (int)checksum;
}
