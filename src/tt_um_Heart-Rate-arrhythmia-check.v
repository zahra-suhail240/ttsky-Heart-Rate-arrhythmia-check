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

  clock_divider u_divider ();

  interval_detection u_interval (.clk_div(clk_div),
                                  .rst_n (rst_n),
                                  .pulse_in (ui_in[0]),           // heartbeat pulse input
                                  .rr_interval_ms (rr_interval_ms),
                                  .new_rr_pulse (new_rr));

  live_arrhythmia_comparator u_live_comp ();

  final_analysis_comparator u_final ();


endmodule


/*
SUB-MODULES
You can define sub-modules here. Make sure to connect them properly in the main module above
*/

module clock_divider ();

 



endmodule


module interval_detection (input  wire  clk_div,       //clock_divider
                            input  wire rst_n,
                            input  wire pulse_in,      // heartbeat pulse (e.g. ui_in[0] – assume rising edge per beat)
                            output reg  [11:0] rr_interval_ms, // most recent RR in milliseconds
                            output reg  new_rr_pulse   // high for 1 cycle when new RR is ready
    );
          

reg pulse_prev;
    wire rising_edge = pulse_in & ~pulse_prev;

    reg [11:0] counter;  // time since last beat

    always @(posedge clk_div or negedge rst_n) begin
        if (!rst_n) begin
            pulse_prev     <= 1'b0;
            counter        <= 12'd0;
            rr_interval_ms <= 12'd0;
            new_rr_pulse   <= 1'b0;
        end else begin
            pulse_prev     <= pulse_in;
            new_rr_pulse   <= 1'b0;

            if (rising_edge) begin
                rr_interval_ms <= counter;
                counter        <= 12'd0;
                new_rr_pulse   <= 1'b1;
            end else if (counter != 12'hFFF) begin
                counter <= counter + 1'b1;   // saturate at 4095 ms (~15 bpm)
            end
        end
    end

endmodule


module live_arrhythmia_comparator ();

   

endmodule


module final_analysis_comparator ();



endmodule
