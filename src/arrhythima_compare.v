module arrhythmia_compare (
    input  wire        clk,            // use the SAME clock domain as interval_detection (clk_div / 1kHz) OR your main clk
    input  wire        rst_n,

    input  wire [11:0] rr_interval_ms,  // from interval_detection
    input  wire        new_rr_pulse,     // 1-cycle strobe when rr_interval_ms is updated

    output reg  [1:0]  type_code,       // 00=tachy, 01=normal, 10=brady
    output reg         tachy_flag,
    output reg         normal_flag,
    output reg         brady_flag,

    output reg  [15:0] total_beats,
    output reg  [15:0] tachy_count,
    output reg  [15:0] normal_count,
    output reg  [15:0] brady_count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            type_code   <= 2'b01;
            tachy_flag  <= 1'b0;
            normal_flag <= 1'b1;
            brady_flag  <= 1'b0;

            total_beats  <= 16'd0;
            tachy_count  <= 16'd0;
            normal_count <= 16'd0;
            brady_count  <= 16'd0;
        end else begin
            if (new_rr_pulse) begin
                // every new RR interval means we detected a beat
                total_beats <= total_beats + 16'd1;

                // classify based on rr_interval_ms
                if (rr_interval_ms < 12'd600) begin
                    // Tachycardia (<0.6s)
                    type_code   <= 2'b00;
                    tachy_flag  <= 1'b1;
                    normal_flag <= 1'b0;
                    brady_flag  <= 1'b0;

                    tachy_count <= tachy_count + 16'd1;

                end else if (rr_interval_ms <= 12'd1000) begin
                    // Normal (0.6s .. 1.0s)
                    type_code   <= 2'b01;
                    tachy_flag  <= 1'b0;
                    normal_flag <= 1'b1;
                    brady_flag  <= 1'b0;

                    normal_count <= normal_count + 16'd1;

                end else begin
                    // Bradycardia (>1.0s)
                    type_code   <= 2'b10;
                    tachy_flag  <= 1'b0;
                    normal_flag <= 1'b0;
                    brady_flag  <= 1'b1;

                    brady_count <= brady_count + 16'd1;
                end
            end
        end
    end

endmodule
