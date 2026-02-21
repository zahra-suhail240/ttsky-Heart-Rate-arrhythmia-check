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