`timescale 1ns/1ps

module raw_hazard_tb;

    logic clk;
    logic reset;

    logic [31:0] instruction_data;
    logic [31:0] instruction_address;

    logic [31:0] data_read_data;
    logic [31:0] data_address;
    logic [31:0] data_write_data;
    logic        data_mem_write;
    logic [2:0]  data_funct3;

    logic [31:0] debug_a0;

    integer test_case;


    // Clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;


    // No data-memory access is needed in these tests
    assign data_read_data = 32'b0;


    // DUT
    rv32i_pipelined_core dut (
        .clk(clk),
        .reset(reset),

        .instruction_data(instruction_data),
        .instruction_address(instruction_address),

        .data_read_data(data_read_data),
        .data_address(data_address),
        .data_write_data(data_write_data),
        .data_mem_write(data_mem_write),
        .data_funct3(data_funct3),

        .debug_a0(debug_a0)
    );


    // Instruction memory model
    always_comb begin
        instruction_data = 32'h00000013; // NOP

        case (test_case)

            // Test 1: MEM -> EX forwarding
            //
            // addi x5, x0, 7
            // add  x10, x5, x5
            //
            // Expected x10 = 14
            1: begin
                case (instruction_address)
                    32'h0000_0000:
                        instruction_data = 32'h00700293;

                    32'h0000_0004:
                        instruction_data = 32'h00528533;

                    default:
                        instruction_data = 32'h00000013;
                endcase
            end


            // Test 2: WB -> EX forwarding
            //
            // addi x5, x0, 7
            // addi x8, x0, 3
            // add  x10, x5, x5
            //
            // Expected x10 = 14
            2: begin
                case (instruction_address)
                    32'h0000_0000:
                        instruction_data = 32'h00700293;

                    32'h0000_0004:
                        instruction_data = 32'h00300413;

                    32'h0000_0008:
                        instruction_data = 32'h00528533;

                    default:
                        instruction_data = 32'h00000013;
                endcase
            end


            // Test 3: MEM must have priority over WB
            //
            // addi x5, x0, 1
            // addi x5, x0, 2
            // add  x10, x5, x0
            //
            // Expected x10 = 2, not 1
            3: begin
                case (instruction_address)
                    32'h0000_0000:
                        instruction_data = 32'h00100293;

                    32'h0000_0004:
                        instruction_data = 32'h00200293;

                    32'h0000_0008:
                        instruction_data = 32'h00028533;

                    default:
                        instruction_data = 32'h00000013;
                endcase
            end

            default:
                instruction_data = 32'h00000013;

        endcase
    end


    task automatic reset_cpu;
        begin
            reset = 1'b1;

            repeat (3)
                @(posedge clk);

            @(negedge clk);
            reset = 1'b0;
        end
    endtask


    task automatic run_test(
        input integer test_number,
        input logic [31:0] expected_a0,
        input string test_name
    );
        begin
            test_case = test_number;

            reset_cpu();

            // Enough cycles for all instructions to reach WB
            repeat (10)
                @(posedge clk);

            #1;

            if (debug_a0 !== expected_a0) begin
                $display(
                    "FAIL: %s | expected a0=%0d, got a0=%0d",
                    test_name,
                    expected_a0,
                    debug_a0
                );
                $fatal(1);
            end

            $display(
                "PASS: %s | a0=%0d",
                test_name,
                debug_a0
            );
        end
    endtask


    initial begin
        $dumpfile("raw_hazard.vcd");
        $dumpvars(0, raw_hazard_tb);

        reset     = 1'b1;
        test_case = 0;

        run_test(
            1,
            32'd14,
            "MEM -> EX forwarding"
        );

        run_test(
            2,
            32'd14,
            "WB -> EX forwarding"
        );

        run_test(
            3,
            32'd2,
            "MEM priority over WB"
        );

        $display("PASS: all RAW forwarding tests passed");

        $finish;
    end

endmodule