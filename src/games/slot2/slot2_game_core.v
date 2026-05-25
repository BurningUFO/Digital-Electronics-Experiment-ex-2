module slot2_game_core (
    input  wire        clk,
    input  wire        reset,
    input  wire        selected,
    input  wire        frame_tick,
    input  wire        gravity_tick,
    input  wire        move_left,
    input  wire        move_right,
    input  wire        rotate_cw,
    input  wire        soft_drop,
    input  wire        hard_drop,
    output wire [199:0] board,
    output wire [2:0]  piece_type,
    output wire [1:0]  piece_rotation,
    output wire [3:0]  piece_x,
    output wire [5:0]  piece_y,
    output wire [2:0]  next_type,
    output wire [15:0] score,
    output wire [9:0]  lines,
    output wire [3:0]  level,
    output wire [5:0]  ghost_piece_y,
    output wire        game_over,
    output reg         lock_pulse,
    output reg         line_clear_pulse,
    output reg  [2:0]  line_clear_count
);

    localparam ST_PLAYING       = 3'd0;
    localparam ST_HARD_DROP     = 3'd1;
    localparam ST_CLEAR_ANIM    = 3'd2;
    localparam ST_ROW_SCAN      = 3'd3;
    localparam ST_COMPACT_PREP  = 3'd4;
    localparam ST_COMPACT_SCAN  = 3'd5;
    localparam ST_COMPACT_APPLY = 3'd6;
    localparam ST_GAME_OVER     = 3'd7;

    reg [2:0] state;
    reg [4:0] clear_delay;

    reg [199:0] board_reg;
    reg [199:0] compact_reg;
    reg [2:0] cur_type;
    reg [1:0] cur_rot;
    reg [3:0] cur_x;
    reg [5:0] cur_y;
    reg [5:0] ghost_y_reg;
    reg [2:0] nxt_type;
    reg [15:0] lfsr;
    reg [15:0] score_reg;
    reg [9:0]  total_lines;
    reg [3:0]  level_reg;
    reg        spawn_req;
    reg [19:0] rows_full_reg;
    reg [4:0]  row_scan_idx;
    reg [4:0]  compact_src;
    reg [4:0]  compact_dst;
    reg [2:0]  rows_to_clear;

    assign board = board_reg;
    assign piece_type = cur_type;
    assign piece_rotation = cur_rot;
    assign piece_x = cur_x;
    assign piece_y = cur_y;
    assign next_type = nxt_type;
    assign score = score_reg;
    assign lines = total_lines;
    assign level = level_reg;
    assign game_over = (state == ST_GAME_OVER);

    function [15:0] piece_shape;
        input [2:0] ptype;
        input [1:0] prot;
        begin
            case ({ptype, prot})
                {3'd0, 2'd0}: piece_shape = 16'h0F00;
                {3'd0, 2'd1}: piece_shape = 16'h1111;
                {3'd0, 2'd2}: piece_shape = 16'h00F0;
                {3'd0, 2'd3}: piece_shape = 16'h1111;

                {3'd1, 2'd0}: piece_shape = 16'h0330;
                {3'd1, 2'd1}: piece_shape = 16'h0330;
                {3'd1, 2'd2}: piece_shape = 16'h0330;
                {3'd1, 2'd3}: piece_shape = 16'h0330;

                {3'd2, 2'd0}: piece_shape = 16'h0072;
                {3'd2, 2'd1}: piece_shape = 16'h0232;
                {3'd2, 2'd2}: piece_shape = 16'h0270;
                {3'd2, 2'd3}: piece_shape = 16'h0131;

                {3'd3, 2'd0}: piece_shape = 16'h0063;
                {3'd3, 2'd1}: piece_shape = 16'h0132;
                {3'd3, 2'd2}: piece_shape = 16'h0063;
                {3'd3, 2'd3}: piece_shape = 16'h0132;

                {3'd4, 2'd0}: piece_shape = 16'h0036;
                {3'd4, 2'd1}: piece_shape = 16'h0231;
                {3'd4, 2'd2}: piece_shape = 16'h0036;
                {3'd4, 2'd3}: piece_shape = 16'h0231;

                {3'd5, 2'd0}: piece_shape = 16'h0074;
                {3'd5, 2'd1}: piece_shape = 16'h0223;
                {3'd5, 2'd2}: piece_shape = 16'h0170;
                {3'd5, 2'd3}: piece_shape = 16'h0311;

                {3'd6, 2'd0}: piece_shape = 16'h0071;
                {3'd6, 2'd1}: piece_shape = 16'h0322;
                {3'd6, 2'd2}: piece_shape = 16'h0470;
                {3'd6, 2'd3}: piece_shape = 16'h0113;
                default: piece_shape = 16'h0000;
            endcase
        end
    endfunction

    function [9:0] board_row;
        input [4:0] row_idx;
        begin
            case (row_idx)
                5'd0:  board_row = board_reg[0 +: 10];
                5'd1:  board_row = board_reg[10 +: 10];
                5'd2:  board_row = board_reg[20 +: 10];
                5'd3:  board_row = board_reg[30 +: 10];
                5'd4:  board_row = board_reg[40 +: 10];
                5'd5:  board_row = board_reg[50 +: 10];
                5'd6:  board_row = board_reg[60 +: 10];
                5'd7:  board_row = board_reg[70 +: 10];
                5'd8:  board_row = board_reg[80 +: 10];
                5'd9:  board_row = board_reg[90 +: 10];
                5'd10: board_row = board_reg[100 +: 10];
                5'd11: board_row = board_reg[110 +: 10];
                5'd12: board_row = board_reg[120 +: 10];
                5'd13: board_row = board_reg[130 +: 10];
                5'd14: board_row = board_reg[140 +: 10];
                5'd15: board_row = board_reg[150 +: 10];
                5'd16: board_row = board_reg[160 +: 10];
                5'd17: board_row = board_reg[170 +: 10];
                5'd18: board_row = board_reg[180 +: 10];
                5'd19: board_row = board_reg[190 +: 10];
                default: board_row = 10'h3ff;
            endcase
        end
    endfunction

    function [3:0] shape_row_bits;
        input [15:0] shape;
        input [1:0] row_idx;
        begin
            case (row_idx)
                2'd0: shape_row_bits = shape[3:0];
                2'd1: shape_row_bits = shape[7:4];
                2'd2: shape_row_bits = shape[11:8];
                default: shape_row_bits = shape[15:12];
            endcase
        end
    endfunction

    function collision;
        input [3:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        reg hit;
        integer row;
        reg [6:0] abs_y;
        reg [15:0] shape;
        reg [3:0] row_shape;
        reg [13:0] shifted_shape;
        begin
            shape = piece_shape(ptype, prot);
            hit = 1'b0;
            for (row = 0; row < 4; row = row + 1) begin
                row_shape = shape_row_bits(shape, row[1:0]);
                if (row_shape != 4'd0) begin
                    abs_y = py + {5'd0, row[1:0]};
                    if (px >= 4'd10 || abs_y[6] || abs_y >= 7'd20) begin
                        hit = 1'b1;
                    end else begin
                        shifted_shape = {10'd0, row_shape} << px;
                        if (|shifted_shape[13:10]) begin
                            hit = 1'b1;
                        end else if (|(board_row(abs_y[4:0]) & shifted_shape[9:0])) begin
                            hit = 1'b1;
                        end
                    end
                end
            end
            collision = hit;
        end
    endfunction

    function [9:0] level_goal;
        input [3:0] lvl;
        begin
            case (lvl)
                4'd0:  level_goal = 10'd10;
                4'd1:  level_goal = 10'd20;
                4'd2:  level_goal = 10'd30;
                4'd3:  level_goal = 10'd40;
                4'd4:  level_goal = 10'd50;
                4'd5:  level_goal = 10'd60;
                4'd6:  level_goal = 10'd70;
                4'd7:  level_goal = 10'd80;
                4'd8:  level_goal = 10'd90;
                4'd9:  level_goal = 10'd100;
                4'd10: level_goal = 10'd110;
                4'd11: level_goal = 10'd120;
                4'd12: level_goal = 10'd130;
                4'd13: level_goal = 10'd140;
                4'd14: level_goal = 10'd150;
                default: level_goal = 10'd160;
            endcase
        end
    endfunction

    // lock piece into board
    function [199:0] lock_to_board;
        input [199:0] old_board;
        input [3:0] px;
        input [6:0] py;
        input [1:0] prot;
        input [2:0] ptype;
        integer row;
        reg [6:0] abs_y;
        reg [199:0] new_board;
        reg [15:0] shape;
        reg [3:0] row_shape;
        reg [13:0] shifted_shape;
        begin
            shape = piece_shape(ptype, prot);
            new_board = old_board;
            for (row = 0; row < 4; row = row + 1) begin
                row_shape = shape_row_bits(shape, row[1:0]);
                abs_y = py + {5'd0, row[1:0]};
                if (row_shape != 4'd0 && px < 4'd10 && !abs_y[6] && abs_y < 7'd20) begin
                    shifted_shape = {10'd0, row_shape} << px;
                    case (abs_y[4:0])
                        5'd0:  new_board[0 +: 10]   = old_board[0 +: 10]   | shifted_shape[9:0];
                        5'd1:  new_board[10 +: 10]  = old_board[10 +: 10]  | shifted_shape[9:0];
                        5'd2:  new_board[20 +: 10]  = old_board[20 +: 10]  | shifted_shape[9:0];
                        5'd3:  new_board[30 +: 10]  = old_board[30 +: 10]  | shifted_shape[9:0];
                        5'd4:  new_board[40 +: 10]  = old_board[40 +: 10]  | shifted_shape[9:0];
                        5'd5:  new_board[50 +: 10]  = old_board[50 +: 10]  | shifted_shape[9:0];
                        5'd6:  new_board[60 +: 10]  = old_board[60 +: 10]  | shifted_shape[9:0];
                        5'd7:  new_board[70 +: 10]  = old_board[70 +: 10]  | shifted_shape[9:0];
                        5'd8:  new_board[80 +: 10]  = old_board[80 +: 10]  | shifted_shape[9:0];
                        5'd9:  new_board[90 +: 10]  = old_board[90 +: 10]  | shifted_shape[9:0];
                        5'd10: new_board[100 +: 10] = old_board[100 +: 10] | shifted_shape[9:0];
                        5'd11: new_board[110 +: 10] = old_board[110 +: 10] | shifted_shape[9:0];
                        5'd12: new_board[120 +: 10] = old_board[120 +: 10] | shifted_shape[9:0];
                        5'd13: new_board[130 +: 10] = old_board[130 +: 10] | shifted_shape[9:0];
                        5'd14: new_board[140 +: 10] = old_board[140 +: 10] | shifted_shape[9:0];
                        5'd15: new_board[150 +: 10] = old_board[150 +: 10] | shifted_shape[9:0];
                        5'd16: new_board[160 +: 10] = old_board[160 +: 10] | shifted_shape[9:0];
                        5'd17: new_board[170 +: 10] = old_board[170 +: 10] | shifted_shape[9:0];
                        5'd18: new_board[180 +: 10] = old_board[180 +: 10] | shifted_shape[9:0];
                        5'd19: new_board[190 +: 10] = old_board[190 +: 10] | shifted_shape[9:0];
                        default: ;
                    endcase
                    if (|shifted_shape[13:10]) begin
                        new_board = old_board;
                    end
                end
            end
            lock_to_board = new_board;
        end
    endfunction

    assign ghost_piece_y = ghost_y_reg;

    wire [9:0] next_line_total = total_lines + {7'd0, rows_to_clear};
    wire [9:0] next_level_goal = level_goal(level_reg);
    wire [15:0] level_factor = {12'd0, level_reg} + 16'd1;
    wire current_row_full = &board_row(row_scan_idx);

    always @(posedge clk) begin
        if (reset) begin
            state <= ST_PLAYING;
            clear_delay <= 5'd0;
            board_reg <= 200'd0;
            compact_reg <= 200'd0;
            cur_type <= 3'd0;
            cur_rot <= 2'd0;
            cur_x <= 4'd3;
            cur_y <= 6'd0;
            ghost_y_reg <= 6'd0;
            nxt_type <= 3'd0;
            lfsr <= 16'hACE1;
            score_reg <= 16'd0;
            total_lines <= 10'd0;
            level_reg <= 4'd0;
            spawn_req <= 1'b1;
            rows_full_reg <= 20'd0;
            row_scan_idx <= 5'd0;
            compact_src <= 5'd0;
            compact_dst <= 5'd0;
            rows_to_clear <= 3'd0;
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            line_clear_count <= 3'd0;
        end else if (selected) begin
            lock_pulse <= 1'b0;
            line_clear_pulse <= 1'b0;
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            case (state)
                ST_PLAYING: begin
                    if (spawn_req) begin
                        spawn_req <= 1'b0;
                        cur_type <= nxt_type;
                        cur_rot <= 2'd0;
                        cur_x <= 4'd3;
                        cur_y <= 6'd0;
                        ghost_y_reg <= 6'd0;
                        nxt_type <= (lfsr[2:0] < 3'd7) ? lfsr[2:0] :
                                    (lfsr[5:3] < 3'd7) ? lfsr[5:3] : 3'd0;
                        if (collision(4'd3, 7'd0, 2'd0, nxt_type)) begin
                            state <= ST_GAME_OVER;
                        end
                    end else begin
                        if (!collision(cur_x, {1'b0, ghost_y_reg} + 7'd1, cur_rot, cur_type)) begin
                            ghost_y_reg <= ghost_y_reg + 6'd1;
                        end

                        if (hard_drop) begin
                            state <= ST_HARD_DROP;
                        end else begin
                            if (rotate_cw) begin
                                if (!collision(cur_x, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x - 4'd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x - 4'd1;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x + 4'd1, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x + 4'd1;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x - 4'd2, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x - 4'd2;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x + 4'd2, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x + 4'd2;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x - 4'd3, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x - 4'd3;
                                    ghost_y_reg <= cur_y;
                                end else if (!collision(cur_x + 4'd3, {1'b0, cur_y}, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_x <= cur_x + 4'd3;
                                    ghost_y_reg <= cur_y;
                                end else if (cur_y > 6'd0 && !collision(cur_x, {1'b0, cur_y} - 7'd1, cur_rot + 2'd1, cur_type)) begin
                                    cur_rot <= cur_rot + 2'd1;
                                    cur_y <= cur_y - 6'd1;
                                    ghost_y_reg <= cur_y - 6'd1;
                                end
                            end else if (move_left && !move_right &&
                                         !collision(cur_x - 4'd1, {1'b0, cur_y}, cur_rot, cur_type)) begin
                                cur_x <= cur_x - 4'd1;
                                ghost_y_reg <= cur_y;
                            end else if (move_right && !move_left &&
                                         !collision(cur_x + 4'd1, {1'b0, cur_y}, cur_rot, cur_type)) begin
                                cur_x <= cur_x + 4'd1;
                                ghost_y_reg <= cur_y;
                            end else if (gravity_tick || soft_drop) begin
                                if (!collision(cur_x, {1'b0, cur_y} + 7'd1, cur_rot, cur_type)) begin
                                    cur_y <= cur_y + 6'd1;
                                    ghost_y_reg <= cur_y + 6'd1;
                                end else begin
                                    board_reg <= lock_to_board(board_reg, cur_x, {1'b0, cur_y}, cur_rot, cur_type);
                                    lock_pulse <= 1'b1;
                                    state <= ST_CLEAR_ANIM;
                                    clear_delay <= 5'd20;
                                end
                            end
                        end
                    end
                end

                ST_HARD_DROP: begin
                    if (!collision(cur_x, {1'b0, cur_y} + 7'd1, cur_rot, cur_type)) begin
                        cur_y <= cur_y + 6'd1;
                        ghost_y_reg <= cur_y + 6'd1;
                    end else begin
                        board_reg <= lock_to_board(board_reg, cur_x, {1'b0, cur_y}, cur_rot, cur_type);
                        lock_pulse <= 1'b1;
                        state <= ST_CLEAR_ANIM;
                        clear_delay <= 5'd20;
                    end
                end

                ST_CLEAR_ANIM: begin
                    if (clear_delay > 5'd0) begin
                        clear_delay <= clear_delay - 5'd1;
                    end else begin
                        rows_full_reg <= 20'd0;
                        rows_to_clear <= 3'd0;
                        row_scan_idx <= 5'd0;
                        state <= ST_ROW_SCAN;
                    end
                end

                ST_ROW_SCAN: begin
                    if (current_row_full) begin
                        rows_full_reg[row_scan_idx] <= 1'b1;
                        if (rows_to_clear < 3'd4) rows_to_clear <= rows_to_clear + 3'd1;
                    end

                    if (row_scan_idx == 5'd19) begin
                        state <= ST_COMPACT_PREP;
                    end else begin
                        row_scan_idx <= row_scan_idx + 5'd1;
                    end
                end

                ST_COMPACT_PREP: begin
                    compact_reg <= 200'd0;
                    compact_src <= 5'd19;
                    compact_dst <= 5'd19;
                    state <= ST_COMPACT_SCAN;
                end

                ST_COMPACT_SCAN: begin
                    if (!rows_full_reg[compact_src]) begin
                        compact_reg[compact_dst*10 +: 10] <= board_reg[compact_src*10 +: 10];
                        if (compact_dst > 5'd0) compact_dst <= compact_dst - 5'd1;
                    end

                    if (compact_src == 5'd0) begin
                        state <= ST_COMPACT_APPLY;
                    end else begin
                        compact_src <= compact_src - 5'd1;
                    end
                end

                ST_COMPACT_APPLY: begin
                    if (rows_to_clear > 3'd0) begin
                        board_reg <= compact_reg;
                        line_clear_pulse <= 1'b1;
                        line_clear_count <= rows_to_clear;
                        case (rows_to_clear)
                            3'd1: score_reg <= score_reg + 16'd100 * level_factor;
                            3'd2: score_reg <= score_reg + 16'd300 * level_factor;
                            3'd3: score_reg <= score_reg + 16'd500 * level_factor;
                            3'd4: score_reg <= score_reg + 16'd800 * level_factor;
                            default: ;
                        endcase
                        total_lines <= total_lines + {7'd0, rows_to_clear};
                        if (next_line_total >= next_level_goal && level_reg < 4'd15)
                            level_reg <= level_reg + 4'd1;
                    end
                    ghost_y_reg <= 6'd0;
                    state <= ST_PLAYING;
                    spawn_req <= 1'b1;
                    rows_to_clear <= 3'd0;
                end

                ST_GAME_OVER: begin
                end
            endcase
        end
    end

endmodule

