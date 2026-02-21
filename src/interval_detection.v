module interval_detection (
    input  wire        clk_div,         // 1 kHz clock (1 tick = 1 ms)
    input  wire        rst_n,
    input  wire        pulse_in,        // heartbeat pulse from ui_in[0]
    output reg  [11:0] rr_interval_ms,  // most recent RR in milliseconds
    output reg         new_rr_pulse     // high for 1 cycle when new RR is ready
);

    // --------------------------------------------------------
    // Debounce logic
    // pulse_in must be held HIGH for DEBOUNCE_MS consecutive
    // 1 kHz ticks before it is considered a valid beat.
    // At 1 kHz, 10 ticks = 10 ms debounce window.
    // --------------------------------------------------------
    localparam DEBOUNCE_MS = 4'd10;

    reg [3:0]  db_cnt;       // counts how long pulse_in has been HIGH
    reg        db_stable;    // goes HIGH once pulse_in held for DEBOUNCE_MS
    reg        db_prev;      // previous value of db_stable for edge detect

    // Rising edge on the DEBOUNCED signal (not raw pulse_in)
    wire beat_detected = db_stable && !db_prev;

    // --------------------------------------------------------
    // RR interval counter
    // --------------------------------------------------------
    reg [11:0] counter;      // counts ms since last valid beat

    always @(posedge clk_div or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt         <= 4'd0;
            db_stable      <= 1'b0;
            db_prev        <= 1'b0;
            counter        <= 12'd0;
            rr_interval_ms <= 12'd0;
            new_rr_pulse   <= 1'b0;
        end else begin
            new_rr_pulse <= 1'b0;   // default: no strobe

            // --- Debounce counter ---
            if (pulse_in) begin
                if (db_cnt < DEBOUNCE_MS)
                    db_cnt <= db_cnt + 4'd1;
                else
                    db_stable <= 1'b1;   // held HIGH long enough — valid
            end else begin
                db_cnt    <= 4'd0;       // reset counter if pulse drops
                db_stable <= 1'b0;
            end

            // --- Edge detect on debounced signal ---
            db_prev <= db_stable;

            // --- On valid beat rising edge ---
            if (beat_detected) begin
                rr_interval_ms <= counter;   // capture interval
                counter        <= 12'd0;     // restart interval counter
                new_rr_pulse   <= 1'b1;      // strobe for 1 cycle
            end else if (counter != 12'hFFF) begin
                counter <= counter + 12'd1;  // count ms, saturate at 4095
            end

        end
    end

endmodule