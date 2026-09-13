`timescale 1ns/1ps

// Wrong-path stores must never reach a peripheral, even for one cycle.
module soc_flush_tb;
    logic clk = 0, reset = 1;
    logic [31:0] gpio_out, debug_a0;
    logic uart_tx;
    integer writes;

    always #5 clk = ~clk;
    rv32i_pipelined_soc dut (
        .clk(clk), .reset(reset), .btn(1'b1),
        .gpio_out(gpio_out), .debug_a0(debug_a0), .uart_tx(uart_tx)
    );

    // Check the accepted bus transaction, not just the final GPIO value.
    always @(posedge clk) begin
        if (reset) writes = 0;
        else if (dut.data_mem_write) begin
            if (dut.data_address !== 32'h10000000 || dut.data_write_data !== 32'd7)
                $fatal(1, "Wrong-path store: address=%h data=%h",
                       dut.data_address, dut.data_write_data);
            writes = writes + 1;
        end
    end

    initial begin
        for (integer redirect = 0; redirect < 3; redirect = redirect + 1) begin
            // Rotate peripherals through both flushed pipeline slots.
            for (integer peripheral = 0; peripheral < 3; peripheral = peripheral + 1) begin
                @(negedge clk); reset = 1;
                repeat (2) @(posedge clk);
                @(negedge clk);
                for (integer i = 0; i < 256; i = i + 1)
                    dut.imem.memory[i] = 32'h00000013;
                dut.imem.memory[0] = 32'h10000437; // lui x8, 0x10000 (GPIO)
                dut.imem.memory[1] = 32'h200004b7; // lui x9, 0x20000 (UART)
                dut.imem.memory[2] = 32'h30000937; // lui x18,0x30000 (timer)
                dut.imem.memory[3] = 32'h05500313; // addi x6,x0,85 (forbidden data)
                dut.imem.memory[4] = 32'h02400293; // addi x5,x0,36 (target)
                case (redirect)
                    0: dut.imem.memory[5] = 32'h00000863; // beq x0,x0,+16
                    1: dut.imem.memory[5] = 32'h010000ef; // jal x1,+16
                    2: dut.imem.memory[5] = 32'h000280e7; // jalr x1,0(x5)
                endcase
                case (peripheral)
                    0: begin
                        dut.imem.memory[6] = 32'h00642023; // sw x6,0(x8)
                        dut.imem.memory[7] = 32'h0064a023; // sw x6,0(x9)
                    end
                    1: begin
                        dut.imem.memory[6] = 32'h0064a023; // sw x6,0(x9)
                        dut.imem.memory[7] = 32'h00692023; // sw x6,0(x18)
                    end
                    2: begin
                        dut.imem.memory[6] = 32'h00692023; // sw x6,0(x18)
                        dut.imem.memory[7] = 32'h00642023; // sw x6,0(x8)
                    end
                endcase
                dut.imem.memory[9] = 32'h00700313;  // addi x6,x0,7
                dut.imem.memory[10] = 32'h00642023; // sw x6,0(x8) (valid target)
                dut.imem.memory[11] = 32'h0000006f; // jal x0,0
                reset = 0;
                repeat (25) @(posedge clk);
                #1;
                if (writes != 1 || gpio_out !== 32'd7 ||
                    uart_tx !== 1'b1 || dut.timer_busy !== 1'b0)
                    $fatal(1, "Redirect %0d, peripheral %0d: side effect or missing target",
                           redirect, peripheral);
                $display("PASS: MMIO flush redirect=%0d peripheral=%0d", redirect, peripheral);
            end
        end
        $finish;
    end
endmodule
