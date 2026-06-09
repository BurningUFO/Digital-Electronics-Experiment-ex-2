module game_slot2_top (
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
    input  wire        ps2_byte_ready,
    input  wire [7:0]  ps2_byte_data,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
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
    wire signed [4:0] piece_x;
    wire [5:0]  piece_y, ghost_piece_y;
    wire [15:0] score;
    wire [9:0]  lines;
    wire [3:0]  level;
    wire        game_over;
    wire        lock_pulse, line_clear_pulse;
    wire [2:0]  line_clear_count;
    wire [3:0]  render_r;
    wire [3:0]  render_g;
    wire [3:0]  render_b;
    (* keep = "true" *) reg         selected_video_q;
    (* keep = "true" *) reg [199:0] board_video_q;
    (* keep = "true" *) reg [2:0]   piece_type_video_q;
    (* keep = "true" *) reg [1:0]   piece_rotation_video_q;
    (* keep = "true" *) reg signed [4:0] piece_x_video_q;
    (* keep = "true" *) reg [5:0]   piece_y_video_q;
    (* keep = "true" *) reg [5:0]   ghost_piece_y_video_q;
    (* keep = "true" *) reg [2:0]   next_type_video_q;
    (* keep = "true" *) reg [15:0]  score_video_q;
    (* keep = "true" *) reg [9:0]   lines_video_q;
    (* keep = "true" *) reg [3:0]   level_video_q;
    (* keep = "true" *) reg         game_over_video_q;

    // sub-modules
    slot2_tick_gen u_tick (
        .clk(clk), .reset(reset),
        .frame_tick(frame_tick),
        .level(level),
        .gravity_tick(gravity_tick)
    );

    slot2_input u_input (
        .clk(clk), .reset(reset),
        .selected(selected),
        .frame_tick(frame_tick),
        .ps2_byte_ready(ps2_byte_ready),
        .ps2_byte_data(ps2_byte_data),
        .btn_l(btn_l), .btn_r(btn_r),
        .btn_d(btn_d), .btn_u(btn_u), .btn_c(btn_c),
        .move_left(move_left), .move_right(move_right),
        .rotate_cw(rotate_cw),
        .soft_drop(soft_drop), .hard_drop(hard_drop)
    );

    slot2_game_core u_core (
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

    slot2_renderer u_render (
        .clk(clk), .reset(reset),
        .selected(selected_video_q),
        .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .board(board_video_q),
        .piece_type(piece_type_video_q), .piece_rotation(piece_rotation_video_q),
        .piece_x(piece_x_video_q), .piece_y(piece_y_video_q),
        .ghost_piece_y(ghost_piece_y_video_q),
        .next_type(next_type_video_q),
        .score(score_video_q), .lines(lines_video_q), .level(level_video_q),
        .game_over(game_over_video_q),
        .vga_r(render_r), .vga_g(render_g), .vga_b(render_b)
    );

    always @(posedge clk) begin
        if (reset) begin
            selected_video_q <= 1'b0;
            board_video_q <= 200'd0;
            piece_type_video_q <= 3'd0;
            piece_rotation_video_q <= 2'd0;
            piece_x_video_q <= 5'sd0;
            piece_y_video_q <= 6'd0;
            ghost_piece_y_video_q <= 6'd0;
            next_type_video_q <= 3'd0;
            score_video_q <= 16'd0;
            lines_video_q <= 10'd0;
            level_video_q <= 4'd0;
            game_over_video_q <= 1'b0;
        end else if (pixel_tick) begin
            selected_video_q <= selected;
            board_video_q <= board;
            piece_type_video_q <= piece_type;
            piece_rotation_video_q <= piece_rotation;
            piece_x_video_q <= piece_x;
            piece_y_video_q <= piece_y;
            ghost_piece_y_video_q <= ghost_piece_y;
            next_type_video_q <= next_type;
            score_video_q <= score;
            lines_video_q <= lines;
            level_video_q <= level;
            game_over_video_q <= game_over;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (pixel_tick) begin
            vga_r <= render_r;
            vga_g <= render_g;
            vga_b <= render_b;
        end
    end

    // === 7-segment display ===
    reg [15:0] score_sample;
    reg [15:0] score_work;
    reg [2:0]  bcd_state;
    reg [3:0]  d0, d1, d2, d3, d4;
    wire [3:0] l0 = (level >= 4'd10) ? (level - 4'd10) : level;
    wire [3:0] l1 = (level >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] line_hundreds = (lines >= 10'd900) ? 4'd9 :
                               (lines >= 10'd800) ? 4'd8 :
                               (lines >= 10'd700) ? 4'd7 :
                               (lines >= 10'd600) ? 4'd6 :
                               (lines >= 10'd500) ? 4'd5 :
                               (lines >= 10'd400) ? 4'd4 :
                               (lines >= 10'd300) ? 4'd3 :
                               (lines >= 10'd200) ? 4'd2 :
                               (lines >= 10'd100) ? 4'd1 : 4'd0;

    always @(posedge clk) begin
        if (reset) begin
            score_sample <= 16'd0;
            score_work <= 16'd0;
            bcd_state <= 3'd0;
            d0 <= 4'd0;
            d1 <= 4'd0;
            d2 <= 4'd0;
            d3 <= 4'd0;
            d4 <= 4'd0;
        end else begin
            case (bcd_state)
                3'd0: begin
                    if (score_sample != score) begin
                        score_sample <= score;
                        score_work <= score;
                        d0 <= 4'd0;
                        d1 <= 4'd0;
                        d2 <= 4'd0;
                        d3 <= 4'd0;
                        d4 <= 4'd0;
                        bcd_state <= 3'd1;
                    end
                end
                3'd1: begin
                    if (score_work >= 16'd10000) begin
                        score_work <= score_work - 16'd10000;
                        d4 <= d4 + 4'd1;
                    end else begin
                        bcd_state <= 3'd2;
                    end
                end
                3'd2: begin
                    if (score_work >= 16'd1000) begin
                        score_work <= score_work - 16'd1000;
                        d3 <= d3 + 4'd1;
                    end else begin
                        bcd_state <= 3'd3;
                    end
                end
                3'd3: begin
                    if (score_work >= 16'd100) begin
                        score_work <= score_work - 16'd100;
                        d2 <= d2 + 4'd1;
                    end else begin
                        bcd_state <= 3'd4;
                    end
                end
                3'd4: begin
                    if (score_work >= 16'd10) begin
                        score_work <= score_work - 16'd10;
                        d1 <= d1 + 4'd1;
                    end else begin
                        d0 <= score_work[3:0];
                        bcd_state <= 3'd0;
                    end
                end
                default: bcd_state <= 3'd0;
            endcase
        end
    end

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
            3'd7: seg_val = line_hundreds;
            default: seg_val = 4'd0;
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
    reg [11:0] buzz_dur;
    reg        buzz_active;
    reg        buzz_gameover;
    reg        game_over_seen;

    always @(posedge clk) begin
        if (reset) begin
            buzz_cnt <= 17'd0;
            buzz_dur <= 12'd0;
            buzz_active <= 1'b0;
            buzz_gameover <= 1'b0;
            game_over_seen <= 1'b0;
        end else begin
            if (!game_over) begin
                buzz_gameover <= 1'b0;
                game_over_seen <= 1'b0;
            end

            if (lock_pulse) begin
                buzz_active <= 1'b1;
                buzz_dur <= 12'd100;
                buzz_cnt <= 17'd0;
            end else if (line_clear_pulse) begin
                buzz_active <= 1'b1;
                buzz_dur <= 12'd400;
                buzz_cnt <= 17'd0;
            end else if (game_over && !game_over_seen && !buzz_active) begin
                buzz_active <= 1'b1;
                buzz_dur <= 12'd2000;
                buzz_cnt <= 17'd0;
                buzz_gameover <= 1'b1;
                game_over_seen <= 1'b1;
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
        end
    end

    wire tone;
    assign tone = buzz_gameover ? (buzz_cnt[14] ? buzz_cnt[13] : buzz_cnt[12]) : buzz_cnt[12];
    assign buzzer = (buzz_active && selected) ? ~tone : 1'b1;

endmodule

