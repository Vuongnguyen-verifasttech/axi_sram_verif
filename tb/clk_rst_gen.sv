`timescale 1ns/1ps

module clk_rst_gen #(
    parameter CLK_PERIOD = 10  // 100MHz
) (
    output logic clk,
    output logic rst_n
);

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset generation (active-low, synchronous de-assertion)
    initial begin
        rst_n = 0;
        repeat(5) @(posedge clk);   // hold reset 5 cycles
        rst_n = 1;
    end

    // Optional: task để testcase chủ động reset lại
    task automatic do_reset(int cycles = 5);
        rst_n <= 0;
        repeat(cycles) @(posedge clk);
        rst_n <= 1;
    endtask

endmodule : clk_rst_gen