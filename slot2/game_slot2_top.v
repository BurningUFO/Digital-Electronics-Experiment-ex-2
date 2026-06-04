module game_slot4_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        frame_tick,
    input  wire        pixel_tick,
    input  wire        display_active,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        btn_u,
    input  wire        btn_d,
    input  wire        btn_l,
    input  wire        btn_r,
    input  wire        btn_c,
    input  wire [15:0] sw,
    input  wire        ps2_clk,
    input  wire        ps2_data,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire [15:0] led,
    output wire [7:0]  an,
    output wire        ca,
    output wire        cb,
    output wire        cc,
    output wire        cd,
    output wire        ce,
    output wire        cf,
    output wire        cg,
    output wire        dp,
    output wire        buzzer
);

    // internal signals
    wire        gravity_tick;
    wire        move_left, move_right, rotate_cw, soft_drop, hard_drop;
    wire [199:0] board;
    wire [2:0]  piece_type, next_type;
    wire [1:0]  piece_rotation;
    wire [3:0]  piece_x;
    wire [5:0]  piece_y, ghost_piece_y;
    wire [15:0] score;
    wire [9:0]  lines;
    wire [3:0]  level;
    wire        game_over;
    wire        lock_pulse, line_clear_pulse;
    wire [2:0]  line_clear_count;

    // sub-modules
    slot4_tick_gen u_tick (
        .clk(clk), .reset(reset),
        .frame_tick(frame_tick),
        .level(level),
        .gravity_tick(gravity_tick)
    );

    slot4_input u_input (
        .clk(clk), .reset(reset),
        .selected(selected),
        .frame_tick(frame_tick),
        .btn_l(btn_l), .btn_r(btn_r),
        .btn_d(btn_d), .btn_u(btn_u), .btn_c(btn_c),
        .move_left(move_left), .move_right(move_right),
        .rotate_cw(rotate_cw),
        .soft_drop(soft_drop), .hard_drop(hard_drop)
    );

    slot4_game_core u_core (
        .clk(clk), .reset(reset),
        .selected(selected),
        .frame_tick(frame_tick),
        .gravity_tick(gravity_tick),
        .move_left(move_left), .move_right(move_right),
        .rotate_cw(rotate_cw),
        .soft_drop(soft_drop), .hard_drop(hard_drop),
        .board(board),
        .piece_type(piece_type), .piece_rotation(piece_rotation),
        .piece_x(piece_x), .piece_y(piece_y),
        .ghost_piece_y(ghost_piece_y),
        .next_type(next_type),
        .score(score), .lines(lines), .level(level),
        .game_over(game_over),
        .lock_pulse(lock_pulse),
        .line_clear_pulse(line_clear_pulse),
        .line_clear_count(line_clear_count)
    );

    slot4_renderer u_render (
        .clk(clk), .reset(reset),
        .selected(selected),
        .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .board(board),
        .piece_type(piece_type), .piece_rotation(piece_rotation),
        .piece_x(piece_x), .piece_y(piece_y),
        .ghost_piece_y(ghost_piece_y),
        .next_type(next_type),
        .score(score), .lines(lines), .level(level),
        .game_over(game_over),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    // === 7-segment display ===
    // compute BCD digits for score (5 digits, 0-65535) and level (2 digits, 0-15)
    function [3:0] bcd_digit;
        input [15:0] val;
        input [3:0] pos;
        reg [15:0] v;
        reg [3:0] d;
        begin
            v = val; d = 4'd0;
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (v >= 10000) begin d=d+1; v=v-10000; end
            if (pos == 4) bcd_digit = d;
            d = 4'd0;
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (v >= 1000) begin d=d+1; v=v-1000; end
            if (pos == 3) bcd_digit = d;
            d = 4'd0;
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (v >= 100) begin d=d+1; v=v-100; end
            if (pos == 2) bcd_digit = d;
            d = 4'd0;
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (v >= 10) begin d=d+1; v=v-10; end
            if (pos == 1) bcd_digit = d;
            if (pos == 0) bcd_digit = v[3:0];
            if (pos > 4) bcd_digit = 4'd0;
        end
    endfunction

    wire [3:0] d0 = bcd_digit(score, 4'd0);
    wire [3:0] d1 = bcd_digit(score, 4'd1);
    wire [3:0] d2 = bcd_digit(score, 4'd2);
    wire [3:0] d3 = bcd_digit(score, 4'd3);
    wire [3:0] d4 = bcd_digit(score, 4'd4);
    wire [3:0] l0 = bcd_digit({12'd0, level}, 4'd0);
    wire [3:0] l1 = bcd_digit({12'd0, level}, 4'd1);
    wire [3:0] ln0 = bcd_digit({6'd0, lines}, 4'd0);
    wire [3:0] ln1 = bcd_digit({6'd0, lines}, 4'd1);
    wire [3:0] ln2 = bcd_digit({6'd0, lines}, 4'd2);

    // 7-seg scanning counter (~1.5kHz)
    reg [16:0] seg_cnt;
    always @(posedge clk) begin
        if (reset) seg_cnt <= 17'd0;
        else seg_cnt <= seg_cnt + 17'd1;
    end
    wire [2:0] seg_sel = seg_cnt[16:14];

    // digit multiplexer
    reg [3:0] seg_val;
    always @(*) begin
        case (seg_sel)
            3'd0: seg_val = d0;
            3'd1: seg_val = d1;
            3'd2: seg_val = d2;
            3'd3: seg_val = d3;
            3'd4: seg_val = d4;
            3'd5: seg_val = l0;
            3'd6: seg_val = l1;
            3'd7: seg_val = ln2;
        endcase
    end

    // segment lookup (active low)
    reg [6:0] seg_pat;
    always @(*) begin
        case (seg_val)
            4'd0: seg_pat = 7'b0000001;
            4'd1: seg_pat = 7'b1001111;
            4'd2: seg_pat = 7'b0010010;
            4'd3: seg_pat = 7'b0000110;
            4'd4: seg_pat = 7'b1001100;
            4'd5: seg_pat = 7'b0100100;
            4'd6: seg_pat = 7'b0100000;
            4'd7: seg_pat = 7'b0001111;
            4'd8: seg_pat = 7'b0000000;
            4'd9: seg_pat = 7'b0000100;
            default: seg_pat = 7'b1111111;
        endcase
    end

    assign {ca, cb, cc, cd, ce, cf, cg} = seg_pat;
    assign dp = 1'b1;
    assign an = ~(8'b00000001 << seg_sel);

    // === LEDs ===
    // extend hard_drop pulse for visibility
    reg [23:0] hd_flash_cnt;
    always @(posedge clk) begin
        if (reset)        hd_flash_cnt <= 24'd0;
        else if (hard_drop) hd_flash_cnt <= 24'd5000000;
        else if (hd_flash_cnt > 0) hd_flash_cnt <= hd_flash_cnt - 24'd1;
    end
    wire hd_led = |hd_flash_cnt;

    assign led = {1'b0, game_over, hd_led, 1'b0, game_over ? 4'hF : level, 8'd0};

    // === Buzzer ===
    reg [16:0] buzz_cnt;
    reg [9:0]  buzz_dur;
    reg        buzz_active;
    reg        buzz_gameover;

    always @(posedge clk) begin
        if (reset) begin
            buzz_cnt <= 17'd0;
            buzz_dur <= 10'd0;
            buzz_active <= 1'b0;
            buzz_gameover <= 1'b0;
        end else begin
            if (game_over) buzz_gameover <= 1'b1;

            if (lock_pulse) begin
                buzz_active <= 1'b1;
                buzz_dur <= 10'd100;
                buzz_cnt <= 17'd0;
            end else if (line_clear_pulse) begin
                buzz_active <= 1'b1;
                buzz_dur <= 10'd400;
                buzz_cnt <= 17'd0;
            end else if (game_over && buzz_gameover && !buzz_active) begin
                buzz_active <= 1'b1;
                buzz_dur <= 10'd2000;
                buzz_cnt <= 17'd0;
            end else if (buzz_active) begin
                if (buzz_dur > 0) begin
                    buzz_cnt <= buzz_cnt + 17'd1;
                    if (buzz_cnt == 17'd49999) begin
                        buzz_cnt <= 17'd0;
                        buzz_dur <= buzz_dur - 10'd1;
                    end
                end else begin
                    buzz_active <= 1'b0;
                end
            end

            if (!game_over) buzz_gameover <= 1'b0;
        end
    end

    wire tone;
    assign tone = buzz_gameover ? (buzz_cnt[14] ? buzz_cnt[13] : buzz_cnt[12]) : buzz_cnt[12];
    assign buzzer = (buzz_active && selected) ? ~tone : 1'b1;

endmodule
