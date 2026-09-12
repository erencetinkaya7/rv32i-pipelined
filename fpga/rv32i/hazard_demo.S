.section .text
.globl _start

_start:
    addi t0, x0, 5      # t0 = 5
    sw   t0, 0(x0)      # RAM[0] = 5
    lw   t1, 0(x0)      # t1 = RAM[0]
    addi t2, t1, 1      # t2 = 6

    addi a0, x0, 0      # toplam = 0
    addi t3, x0, 3      # sayaç = 3

loop:
    add  a0, a0, t2     # toplam += 6
    addi t3, t3, -1     # sayaç--
    bne  t3, x0, loop   # sayaç sıfır değilse dön

    jal  ra, add_one    # fonksiyona git

done:
    jal  x0, done       # burada sonsuza kadar kal

add_one:
    addi a0, a0, 1      # a0: 18 → 19
    jalr x0, 0(ra)      # dönüş adresine git