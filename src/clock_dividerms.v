// clock_div.v
// 50 MHz -> 1 kHz clock (1 ms period)
// clk_div toggles every 0.5 ms, so the full period is 1.0 ms.

module clock_div (
    input  wire clk,      // 50 MHz
    input  wire rst_n,    // active-low reset
    output reg  clk_div   // 1 kHz clock (1 ms period)
);

    // 0.5 ms at 50 MHz = 25,000 cycles
    // Count 0..24999 then toggle clk_div
    reg [14:0] cnt;  // 15 bits enough (max 24999)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= 15'd0;
            clk_div <= 1'b0;
        end else begin
            if (cnt == 15'd24999) begin
                cnt     <= 15'd0;
                clk_div <= ~clk_div;   // toggle every 0.5 ms
            end else begin
                cnt <= cnt + 15'd1;
            end
        end
    end

endmodule
