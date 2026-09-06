`timescale 1ns/1ps

module load_use_hazard_tb;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [31:0] test_case;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;
    logic [31:0] debug_a0;

    rv32i_pipelined_core dut (
        .clk                 (clk),
        .reset               (reset),
        .instruction_data    (instruction_data),
        .instruction_address (instruction_address),
        .data_read_data      (32'b0),
        .data_address        (data_address),
        .data_write_data     (data_write_data),
        .data_mem_write      (data_mem_write),
        .data_funct3         (data_funct3),
        .debug_a0            (debug_a0)
    );

    always #5 clk = ~clk;

    always_comb begin
        instruction_data = 32'h00000013;

        case (test_case)
            // lw x5, 0(x0)
            // addi x10, x5, 1
            // The load result is consumed immediately: hazard is expected.
            1: begin
                case (instruction_address)
                    32'h00: instruction_data = 32'h00002283;
                    32'h04: instruction_data = 32'h00128513;
                    default: ;
                endcase
            end

            // lw x5, 0(x0)
            // addi x10, x0, 5
            // Immediate bit [24:20] happens to be 5, but rs2 is not used.
            2: begin
                case (instruction_address)
                    32'h00: instruction_data = 32'h00002283;
                    32'h04: instruction_data = 32'h00500513;
                    default: ;
                endcase
            end

            default: ;
        endcase
    end

    task automatic reset_cpu;
        begin
            reset = 1'b1;
            repeat (3) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    task automatic check_hazard(
        input logic [31:0] selected_test,
        input logic expected_hazard,
        input string test_name
    );
        begin
            test_case = selected_test;
            reset_cpu();

            // Observe when the load has reached EX and its consumer is in ID.
            wait (dut.ex_result_src === 2'b01);
            #1;

            if (dut.load_use_hazard !== expected_hazard)
                $fatal(1, "%s: expected hazard=%b, got %b",
                    test_name, expected_hazard, dut.load_use_hazard);

            $display("PASS: %s", test_name);
        end
    endtask

    initial begin
        $dumpfile("load_use_hazard.vcd");
        $dumpvars(0, load_use_hazard_tb);

        check_hazard(1, 1'b1, "load-use hazard detected");
        check_hazard(2, 1'b0, "I-type immediate does not cause false hazard");

        $display("PASS: load-use hazard detection");
        $finish;
    end

endmodule
