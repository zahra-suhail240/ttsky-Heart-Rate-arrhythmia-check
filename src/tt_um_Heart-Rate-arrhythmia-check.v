/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_Heart_Rate_arrhythmia_check (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

  // Instantiate sub-modules here and connect them as needed (you define the ports)
 
 wire clk_div;
 wire [11:0] rr_interval_ms;     // latest RR interval (ms)
  wire new_rr;             // high for 1 cycle when new RR ready

  clock_div u_div (
    .clk(clk),        // 50 MHz
    .rst_n(rst_n),
    .clk_div(clk_1khz)
);

  interval_detection u_interval (.clk_div(clk_div),
                                  .rst_n (rst_n),
                                  .pulse_in (ui_in[0]),           // heartbeat pulse input
                                  .rr_interval_ms (rr_interval_ms),
                                  .new_rr_pulse (new_rr));

  arrhythmia_compare u_arrhythmia_compare (

    .clk_div(clk_div),
    .rst_n(rst_n),

    .rr_interval_ms(rr_interval_ms),
    .new_rr_pulse(new_rr_pulse),

    .type_code(type_code),

    .tachy_flag(tachy_flag),
    .normal_flag(normal_flag),
    .brady_flag(brady_flag),

    .total_beats(total_beats),

    .tachy_count(tachy_count),
    .normal_count(normal_count),
    .brady_count(brady_count)

);

  final_analysis_comparator u_final ();


endmodule



