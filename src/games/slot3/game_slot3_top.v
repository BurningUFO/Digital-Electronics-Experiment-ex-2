module game_slot3_top (
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

    localparam [2:0] ST_START = 3'd0;
    localparam [2:0] ST_PLAY  = 3'd1;
    localparam [2:0] ST_PILL  = 3'd2;
    localparam [2:0] ST_WIN   = 3'd3;
    localparam [2:0] ST_LOSE  = 3'd4;
    localparam [2:0] ST_EXIT  = 3'd5;

    localparam [1:0] TILE_STREET = 2'd0;
    localparam [1:0] TILE_BUILD  = 2'd1;
    localparam [1:0] TILE_TREE   = 2'd2;
    localparam [1:0] TILE_RIVER  = 2'd3;

    localparam [9:0] HERO_SIZE   = 10'd14;
    localparam [9:0] NPC_SIZE    = 10'd12;
    localparam [9:0] PHONE_SIZE  = 10'd20;
    localparam [9:0] WORLD_W     = 10'd640;
    localparam [9:0] WORLD_H     = 10'd480;
    localparam [7:0] ATTRACT_FRAMES = 8'd150;
    localparam [8:0] RED_COOL_FRAMES = 9'd360;
    localparam [8:0] BULLET_FRAMES  = 9'd240;
    localparam [8:0] BULLET_COOL    = 9'd180;
    localparam [7:0] BOMB_FRAMES    = 8'd120;

    wire ps2_ready;
    wire [7:0] ps2_byte;
    reg ps2_break;
    reg ps2_ext;
    reg key_w;
    reg key_a;
    reg key_s;
    reg key_d;
    reg key_space;
    reg key_enter;
    reg key_esc;
    reg key_j;
    reg key_k;
    reg key_up;
    reg key_down;
    reg key_left;
    reg key_right;
    reg key_space_prev;
    reg key_enter_prev;
    reg key_esc_prev;
    reg key_j_prev;
    reg key_k_prev;

    reg [2:0] state;
    reg [1:0] start_choice;
    reg [3:0] start_difficulty;
    reg pill_choice;
    reg [3:0] level;
    reg [15:0] lfsr;
    reg [15:0] map_seed;
    reg [15:0] frame_count;
    reg [9:0] neo_x;
    reg [9:0] neo_y;
    reg [9:0] phone_x;
    reg [9:0] phone_y;
    reg [9:0] red_x;
    reg [9:0] red_y;
    reg [9:0] trinity_x;
    reg [9:0] trinity_y;
    reg has_bullet_time;
    reg [8:0] bullet_timer;
    reg [8:0] bullet_cooldown;
    reg [7:0] attract_timer;
    reg [8:0] red_cooldown;
    reg [1:0] neo_dir;
    reg [5:0] ammo;
    reg [1:0] charges;
    reg shot_active;
    reg [9:0] shot_x;
    reg [9:0] shot_y;
    reg [1:0] shot_dir;
    reg bomb_active;
    reg [7:0] bomb_timer;
    reg [9:0] bomb_x;
    reg [9:0] bomb_y;
    reg crater_active;
    reg [5:0] crater_tile_x;
    reg [4:0] crater_tile_y;
    reg [4:0] smith_count;
    reg [4:0] smith_active;
    reg [7:0] move_phase;
    reg [7:0] rain_phase;
    reg [9:0] next_neo_x;
    reg [9:0] next_neo_y;

    reg [9:0] npc_x [0:7];
    reg [9:0] npc_y [0:7];
    reg [9:0] smith_x [0:7];
    reg [9:0] smith_y [0:7];

    wire input_up;
    wire input_down;
    wire input_left;
    wire input_right;
    wire confirm_pulse;
    wire skill_pulse;
    wire esc_pulse;
    wire shoot_pulse;
    wire bomb_pulse;
    wire bullet_time_active;
    wire player_move_tick;
    wire npc_move_tick;
    wire smith_move_tick;
    wire shot_move_tick;
    wire [5:0] tile_x;
    wire [4:0] tile_y;
    wire [3:0] local_x;
    wire [3:0] local_y;
    wire [1:0] tile_type;
    wire bridge_tile;
    wire walkable_next;
    wire neo_phone_touch;
    wire neo_red_touch;
    wire neo_trinity_touch;
    wire neo_gun_touch;
    wire neo_charge_touch;
    wire [9:0] rain_sum;

    integer i;
    reg [9:0] npc_try_x;
    reg [9:0] npc_try_y;
    reg [9:0] npc_rev_x;
    reg [9:0] npc_rev_y;
    reg [9:0] smith_try_x;
    reg [9:0] smith_try_y;
    reg [9:0] smith_alt_x;
    reg [9:0] smith_alt_y;
    reg smith_chase_now;

    console_ps2_rx u_slot3_ps2_rx (
        .clk(clk),
        .reset(reset | ~selected),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .byte_ready(ps2_ready),
        .byte_data(ps2_byte)
    );

    assign input_up = btn_u | key_w | key_up;
    assign input_down = btn_d | key_s | key_down;
    assign input_left = btn_l | key_a | key_left;
    assign input_right = btn_r | key_d | key_right;
    assign confirm_pulse = (btn_c | key_enter | key_space) & ~(key_enter_prev | key_space_prev);
    assign skill_pulse = key_space & ~key_space_prev;
    assign esc_pulse = key_esc & ~key_esc_prev;
    assign shoot_pulse = key_j & ~key_j_prev;
    assign bomb_pulse = key_k & ~key_k_prev;
    assign bullet_time_active = (bullet_timer != 9'd0);
    assign player_move_tick = frame_tick && (move_phase[0] == 1'b0);
    assign npc_move_tick = frame_tick && (move_phase[2:0] == 3'b000);
    assign smith_move_tick = frame_tick && ((bullet_time_active && (move_phase[4:0] == 5'b00000)) ||
                                            (!bullet_time_active && (move_phase[2:0] <= level[2:0])));
    assign shot_move_tick = frame_tick && (move_phase[0] == 1'b0);
    assign tile_x = pixel_x[9:4];
    assign tile_y = pixel_y[8:4];
    assign local_x = pixel_x[3:0];
    assign local_y = pixel_y[3:0];
    assign tile_type = slot3_tile_type(tile_x, tile_y, map_seed, level);
    assign bridge_tile = slot3_is_bridge(tile_x, tile_y, map_seed);
    assign rain_sum = pixel_y + {2'd0, rain_phase};
    assign walkable_next = slot3_rect_walkable(next_neo_x, next_neo_y, HERO_SIZE, HERO_SIZE, map_seed, level);
    assign neo_phone_touch = slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE, phone_x, phone_y, PHONE_SIZE, PHONE_SIZE);
    assign neo_red_touch = slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE, red_x, red_y, NPC_SIZE, NPC_SIZE);
    assign neo_trinity_touch = slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE, trinity_x, trinity_y, NPC_SIZE, NPC_SIZE);
    assign neo_gun_touch = slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE, 10'd104, 10'd392, 10'd14, 10'd14);
    assign neo_charge_touch = slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE, 10'd520, 10'd104, 10'd14, 10'd14);

    assign led = 16'h0000;
    assign an = 8'hff;
    assign {ca, cb, cc, cd, ce, cf, cg, dp} = 8'hff;
    assign buzzer = 1'b1;

    function slot3_rect_overlap;
        input [9:0] ax;
        input [9:0] ay;
        input [9:0] aw;
        input [9:0] ah;
        input [9:0] bx;
        input [9:0] by;
        input [9:0] bw;
        input [9:0] bh;
        begin
            slot3_rect_overlap = (ax < bx + bw) && (ax + aw > bx) &&
                                 (ay < by + bh) && (ay + ah > by);
        end
    endfunction

    function [1:0] slot3_tile_type;
        input [5:0] tx;
        input [4:0] ty;
        input [15:0] seed;
        input [3:0] lvl;
        reg river_band;
        reg city_block;
        reg tree_patch;
        begin
            river_band = (ty == (5'd8 + seed[2:0])) ||
                         (ty == (5'd9 + seed[2:0])) ||
                         (ty == (5'd10 + seed[2:0]));
            city_block = (((tx[2:0] ^ seed[4:2]) >= 3'd6) &&
                         ((ty[2:0] ^ seed[7:5]) >= 3'd5));
            tree_patch = (((tx[2:0] ^ ty[2:0] ^ seed[10:8]) == 3'd0) ||
                         (((tx[3:0] + ty[3:0] + lvl) & 4'hF) == 4'h3));
            if (crater_active &&
                (tx + 6'd1 >= crater_tile_x) && (tx <= crater_tile_x + 6'd1) &&
                (ty + 5'd1 >= crater_tile_y) && (ty <= crater_tile_y + 5'd1)) begin
                slot3_tile_type = TILE_STREET;
            end else if (slot3_is_bridge(tx, ty, seed)) begin
                slot3_tile_type = TILE_STREET;
            end else if (river_band) begin
                slot3_tile_type = TILE_RIVER;
            end else if (city_block && (tx > 6'd1) && (tx < 6'd38) && (ty > 5'd1) && (ty < 5'd28)) begin
                slot3_tile_type = TILE_BUILD;
            end else if (tree_patch && (tx > 6'd1) && (tx < 6'd38) && (ty > 5'd1) && (ty < 5'd28)) begin
                slot3_tile_type = TILE_TREE;
            end else begin
                slot3_tile_type = TILE_STREET;
            end
        end
    endfunction

    function slot3_is_bridge;
        input [5:0] tx;
        input [4:0] ty;
        input [15:0] seed;
        reg [4:0] ry;
        begin
            ry = 5'd8 + seed[2:0];
            slot3_is_bridge = ((ty >= ry) && (ty <= ry + 5'd2)) &&
                              (((tx >= 6'd8) && (tx <= 6'd10)) ||
                               ((tx >= 6'd27) && (tx <= 6'd30)));
        end
    endfunction

    function slot3_point_walkable;
        input [9:0] px;
        input [9:0] py;
        input [15:0] seed;
        input [3:0] lvl;
        reg [1:0] tt;
        begin
            tt = slot3_tile_type(px[9:4], py[8:4], seed, lvl);
            slot3_point_walkable = (px < WORLD_W) && (py < WORLD_H) &&
                                   (tt != TILE_RIVER) && (tt != TILE_BUILD);
        end
    endfunction

    function slot3_near_neo;
        input [9:0] sx;
        input [9:0] sy;
        reg [10:0] dx;
        reg [10:0] dy;
        begin
            dx = (sx > neo_x) ? (sx - neo_x) : (neo_x - sx);
            dy = (sy > neo_y) ? (sy - neo_y) : (neo_y - sy);
            slot3_near_neo = (dx + dy) < (11'd170 + {5'd0, level, 2'd0});
        end
    endfunction

    function slot3_rect_walkable;
        input [9:0] rx;
        input [9:0] ry;
        input [9:0] rw;
        input [9:0] rh;
        input [15:0] seed;
        input [3:0] lvl;
        begin
            slot3_rect_walkable = slot3_point_walkable(rx, ry, seed, lvl) &&
                                  slot3_point_walkable(rx + rw - 10'd1, ry, seed, lvl) &&
                                  slot3_point_walkable(rx, ry + rh - 10'd1, seed, lvl) &&
                                  slot3_point_walkable(rx + rw - 10'd1, ry + rh - 10'd1, seed, lvl);
        end
    endfunction

    always @(*) begin
        next_neo_x = neo_x;
        next_neo_y = neo_y;
        if (state == ST_PLAY && attract_timer == 8'd0) begin
            if (input_left && neo_x > 10'd2) begin
                next_neo_x = neo_x - 10'd2;
            end else if (input_right && neo_x < WORLD_W - HERO_SIZE - 10'd2) begin
                next_neo_x = neo_x + 10'd2;
            end
            if (input_up && neo_y > 10'd2) begin
                next_neo_y = neo_y - 10'd2;
            end else if (input_down && neo_y < WORLD_H - HERO_SIZE - 10'd2) begin
                next_neo_y = neo_y + 10'd2;
            end
        end
    end

    always @(posedge clk) begin
        if (reset || !selected) begin
            ps2_break <= 1'b0;
            ps2_ext <= 1'b0;
            key_w <= 1'b0;
            key_a <= 1'b0;
            key_s <= 1'b0;
            key_d <= 1'b0;
            key_space <= 1'b0;
            key_enter <= 1'b0;
            key_esc <= 1'b0;
            key_j <= 1'b0;
            key_k <= 1'b0;
            key_up <= 1'b0;
            key_down <= 1'b0;
            key_left <= 1'b0;
            key_right <= 1'b0;
            key_space_prev <= 1'b0;
            key_enter_prev <= 1'b0;
            key_esc_prev <= 1'b0;
            key_j_prev <= 1'b0;
            key_k_prev <= 1'b0;
        end else begin
            key_space_prev <= key_space;
            key_enter_prev <= key_enter;
            key_esc_prev <= key_esc;
            key_j_prev <= key_j;
            key_k_prev <= key_k;
            if (ps2_ready) begin
                if (ps2_byte == 8'hF0) begin
                    ps2_break <= 1'b1;
                end else if (ps2_byte == 8'hE0) begin
                    ps2_ext <= 1'b1;
                end else begin
                    case (ps2_byte)
                        8'h1D: key_w <= ~ps2_break;
                        8'h1C: key_a <= ~ps2_break;
                        8'h1B: key_s <= ~ps2_break;
                        8'h23: key_d <= ~ps2_break;
                        8'h29: key_space <= ~ps2_break;
                        8'h5A: key_enter <= ~ps2_break;
                        8'h76: key_esc <= ~ps2_break;
                        8'h3B: key_j <= ~ps2_break;
                        8'h42: key_k <= ~ps2_break;
                        8'h75: key_up <= ps2_ext ? ~ps2_break : key_up;
                        8'h72: key_down <= ps2_ext ? ~ps2_break : key_down;
                        8'h6B: key_left <= ps2_ext ? ~ps2_break : key_left;
                        8'h74: key_right <= ps2_ext ? ~ps2_break : key_right;
                        default: begin
                        end
                    endcase
                    ps2_break <= 1'b0;
                    ps2_ext <= 1'b0;
                end
            end
        end
    end

    task slot3_start_level;
        input [3:0] new_level;
        input [15:0] seed;
        begin
            level <= new_level;
            map_seed <= seed;
            neo_x <= 10'd32;
            neo_y <= 10'd400;
            phone_x <= 10'd592;
            phone_y <= 10'd48;
            red_x <= 10'd304 + {6'd0, seed[3:0]};
            red_y <= 10'd208 + {6'd0, seed[7:4]};
            trinity_x <= 10'd80 + {3'd0, seed[9:3]};
            trinity_y <= 10'd64 + {4'd0, seed[13:8]};
            has_bullet_time <= 1'b0;
            bullet_timer <= 9'd0;
            bullet_cooldown <= 9'd0;
            attract_timer <= 8'd0;
            red_cooldown <= 9'd0;
            neo_dir <= 2'd1;
            ammo <= 6'd0;
            charges <= 2'd0;
            shot_active <= 1'b0;
            shot_x <= 10'd0;
            shot_y <= 10'd0;
            shot_dir <= 2'd1;
            bomb_active <= 1'b0;
            bomb_timer <= 8'd0;
            bomb_x <= 10'd0;
            bomb_y <= 10'd0;
            crater_active <= 1'b0;
            crater_tile_x <= 6'd0;
            crater_tile_y <= 5'd0;
            smith_count <= (new_level < 4'd7) ? (5'd1 + {1'b0, new_level}) : 5'd8;
            smith_active <= 5'd1;
            smith_x[0] <= 10'd544;
            smith_y[0] <= 10'd384;
            smith_x[1] <= 10'd480;
            smith_y[1] <= 10'd80;
            smith_x[2] <= 10'd112;
            smith_y[2] <= 10'd96;
            smith_x[3] <= 10'd512;
            smith_y[3] <= 10'd240;
            smith_x[4] <= 10'd224;
            smith_y[4] <= 10'd384;
            smith_x[5] <= 10'd352;
            smith_y[5] <= 10'd96;
            smith_x[6] <= 10'd96;
            smith_y[6] <= 10'd304;
            smith_x[7] <= 10'd416;
            smith_y[7] <= 10'd352;
            npc_x[0] <= 10'd144;
            npc_y[0] <= 10'd352;
            npc_x[1] <= 10'd240;
            npc_y[1] <= 10'd96;
            npc_x[2] <= 10'd368;
            npc_y[2] <= 10'd288;
            npc_x[3] <= 10'd496;
            npc_y[3] <= 10'd160;
            npc_x[4] <= 10'd80;
            npc_y[4] <= 10'd224;
            npc_x[5] <= 10'd560;
            npc_y[5] <= 10'd320;
            npc_x[6] <= 10'd288;
            npc_y[6] <= 10'd400;
            npc_x[7] <= 10'd432;
            npc_y[7] <= 10'd64;
        end
    endtask

    always @(posedge clk) begin
        if (reset || !selected) begin
            state <= ST_START;
            start_choice <= 2'd0;
            start_difficulty <= 4'd1;
            pill_choice <= 1'b0;
            level <= 4'd1;
            lfsr <= 16'h3ACE;
            map_seed <= 16'h2345;
            frame_count <= 16'd0;
            move_phase <= 8'd0;
            rain_phase <= 8'd0;
            neo_x <= 10'd32;
            neo_y <= 10'd400;
            phone_x <= 10'd592;
            phone_y <= 10'd48;
            red_x <= 10'd320;
            red_y <= 10'd224;
            trinity_x <= 10'd96;
            trinity_y <= 10'd96;
            has_bullet_time <= 1'b0;
            bullet_timer <= 9'd0;
            bullet_cooldown <= 9'd0;
            attract_timer <= 8'd0;
            red_cooldown <= 9'd0;
            neo_dir <= 2'd1;
            ammo <= 6'd0;
            charges <= 2'd0;
            shot_active <= 1'b0;
            shot_x <= 10'd0;
            shot_y <= 10'd0;
            shot_dir <= 2'd1;
            bomb_active <= 1'b0;
            bomb_timer <= 8'd0;
            bomb_x <= 10'd0;
            bomb_y <= 10'd0;
            crater_active <= 1'b0;
            crater_tile_x <= 6'd0;
            crater_tile_y <= 5'd0;
            smith_count <= 5'd1;
            smith_active <= 5'd1;
            for (i = 0; i < 8; i = i + 1) begin
                npc_x[i] <= 10'd80 + (i[2:0] * 10'd48);
                npc_y[i] <= 10'd80 + (i[2:0] * 10'd32);
                smith_x[i] <= 10'd544;
                smith_y[i] <= 10'd384;
            end
        end else begin
            if (frame_tick) begin
                frame_count <= frame_count + 16'd1;
                move_phase <= move_phase + 8'd1;
                rain_phase <= rain_phase + 8'd3;
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                if (bullet_timer != 9'd0) begin
                    bullet_timer <= bullet_timer - 9'd1;
                end
                if (bullet_cooldown != 9'd0) begin
                    bullet_cooldown <= bullet_cooldown - 9'd1;
                end
                if (attract_timer != 8'd0) begin
                    attract_timer <= attract_timer - 8'd1;
                end
                if (red_cooldown != 9'd0) begin
                    red_cooldown <= red_cooldown - 9'd1;
                end
                if (bomb_active && bomb_timer != 8'd0) begin
                    bomb_timer <= bomb_timer - 8'd1;
                end
            end

            case (state)
                ST_START: begin
                    if ((input_up || input_down) && frame_tick && move_phase[4:0] == 5'd0) begin
                        start_choice <= input_up ? ((start_choice == 2'd0) ? 2'd2 : start_choice - 2'd1) :
                                                    ((start_choice == 2'd2) ? 2'd0 : start_choice + 2'd1);
                    end
                    if ((input_left || input_right) && start_choice == 2'd1 && frame_tick && move_phase[4:0] == 5'd0) begin
                        if (input_left && start_difficulty > 4'd1) begin
                            start_difficulty <= start_difficulty - 4'd1;
                        end else if (input_right && start_difficulty < 4'd5) begin
                            start_difficulty <= start_difficulty + 4'd1;
                        end
                    end
                    if (confirm_pulse) begin
                        if (start_choice == 2'd0) begin
                            slot3_start_level(start_difficulty, lfsr ^ 16'h4D1B);
                            state <= ST_PLAY;
                        end else if (start_choice == 2'd1) begin
                            start_difficulty <= (start_difficulty == 4'd5) ? 4'd1 : start_difficulty + 4'd1;
                        end else begin
                            state <= ST_EXIT;
                        end
                    end
                end
                ST_PLAY: begin
                    if (esc_pulse) begin
                        state <= ST_START;
                    end
                    if (skill_pulse && has_bullet_time && bullet_timer == 9'd0 && bullet_cooldown == 9'd0) begin
                        bullet_timer <= BULLET_FRAMES;
                        bullet_cooldown <= BULLET_FRAMES + BULLET_COOL;
                    end
                    if (player_move_tick && walkable_next) begin
                        neo_x <= next_neo_x;
                        neo_y <= next_neo_y;
                    end
                    if (player_move_tick && attract_timer == 8'd0) begin
                        if (input_up) begin
                            neo_dir <= 2'd0;
                        end else if (input_right) begin
                            neo_dir <= 2'd1;
                        end else if (input_down) begin
                            neo_dir <= 2'd2;
                        end else if (input_left) begin
                            neo_dir <= 2'd3;
                        end
                    end
                    if (neo_red_touch && attract_timer == 8'd0 && red_cooldown == 9'd0) begin
                        attract_timer <= ATTRACT_FRAMES;
                        red_cooldown <= RED_COOL_FRAMES;
                    end
                    if (neo_trinity_touch) begin
                        has_bullet_time <= 1'b1;
                    end
                    if (neo_gun_touch && ammo == 6'd0) begin
                        ammo <= 6'd18;
                    end
                    if (neo_charge_touch && charges == 2'd0) begin
                        charges <= 2'd2;
                    end
                    if (shoot_pulse && ammo != 6'd0 && !shot_active) begin
                        shot_active <= 1'b1;
                        shot_x <= neo_x + 10'd7;
                        shot_y <= neo_y + 10'd7;
                        shot_dir <= neo_dir;
                        ammo <= ammo - 6'd1;
                    end
                    if (bomb_pulse && charges != 2'd0 && !bomb_active) begin
                        bomb_active <= 1'b1;
                        bomb_timer <= BOMB_FRAMES;
                        bomb_x <= (neo_dir == 2'd3 && neo_x > 10'd18) ? neo_x - 10'd18 :
                                  (neo_dir == 2'd1) ? neo_x + 10'd24 : neo_x;
                        bomb_y <= (neo_dir == 2'd0 && neo_y > 10'd18) ? neo_y - 10'd18 :
                                  (neo_dir == 2'd2) ? neo_y + 10'd24 : neo_y;
                        charges <= charges - 2'd1;
                    end
                    if (neo_phone_touch) begin
                        pill_choice <= 1'b0;
                        state <= ST_PILL;
                    end

                    if (shot_active && shot_move_tick) begin
                        if (shot_dir == 2'd0) begin
                            shot_y <= shot_y - 10'd6;
                        end else if (shot_dir == 2'd1) begin
                            shot_x <= shot_x + 10'd6;
                        end else if (shot_dir == 2'd2) begin
                            shot_y <= shot_y + 10'd6;
                        end else begin
                            shot_x <= shot_x - 10'd6;
                        end
                        if (shot_x < 10'd4 || shot_x > 10'd632 || shot_y < 10'd4 || shot_y > 10'd472 ||
                            !slot3_rect_walkable(shot_x, shot_y, 10'd4, 10'd4, map_seed, level)) begin
                            shot_active <= 1'b0;
                        end
                    end

                    if (bomb_active && bomb_timer == 8'd1) begin
                        crater_active <= 1'b1;
                        crater_tile_x <= bomb_x[9:4];
                        crater_tile_y <= bomb_y[8:4];
                        bomb_active <= 1'b0;
                    end

                    if (npc_move_tick) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            npc_try_x = lfsr[i] ? npc_x[i] + 10'd1 : npc_x[i] - 10'd1;
                            npc_try_y = lfsr[i + 4] ? npc_y[i] + 10'd1 : npc_y[i] - 10'd1;
                            npc_rev_x = lfsr[i] ? npc_x[i] - 10'd1 : npc_x[i] + 10'd1;
                            npc_rev_y = lfsr[i + 4] ? npc_y[i] - 10'd1 : npc_y[i] + 10'd1;
                            if (!slot3_rect_walkable(npc_try_x, npc_try_y, NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                                npc_x[i] <= npc_rev_x;
                                npc_y[i] <= npc_rev_y;
                            end else begin
                                npc_x[i] <= npc_try_x;
                                npc_y[i] <= npc_try_y;
                            end
                        end
                        if (slot3_rect_walkable(lfsr[8] ? red_x + 10'd1 : red_x - 10'd1,
                                                lfsr[9] ? red_y + 10'd1 : red_y - 10'd1,
                                                NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                            red_x <= lfsr[8] ? red_x + 10'd1 : red_x - 10'd1;
                            red_y <= lfsr[9] ? red_y + 10'd1 : red_y - 10'd1;
                        end
                        if (slot3_rect_walkable(lfsr[10] ? trinity_x + 10'd1 : trinity_x - 10'd1,
                                                lfsr[11] ? trinity_y + 10'd1 : trinity_y - 10'd1,
                                                NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                            trinity_x <= lfsr[10] ? trinity_x + 10'd1 : trinity_x - 10'd1;
                            trinity_y <= lfsr[11] ? trinity_y + 10'd1 : trinity_y - 10'd1;
                        end
                    end

                    if (smith_move_tick) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < smith_active) begin
                                smith_chase_now = slot3_near_neo(smith_x[i], smith_y[i]);
                                smith_try_x = smith_x[i];
                                smith_try_y = smith_y[i];
                                if (smith_chase_now) begin
                                    smith_try_x = (smith_x[i] + 10'd5 < neo_x) ? smith_x[i] + 10'd1 :
                                                  (smith_x[i] > neo_x + 10'd5) ? smith_x[i] - 10'd1 : smith_x[i];
                                    smith_try_y = (smith_y[i] + 10'd5 < neo_y) ? smith_y[i] + 10'd1 :
                                                  (smith_y[i] > neo_y + 10'd5) ? smith_y[i] - 10'd1 : smith_y[i];
                                end else begin
                                    smith_try_x = lfsr[i] ? smith_x[i] + 10'd1 : smith_x[i] - 10'd1;
                                    smith_try_y = lfsr[i + 4] ? smith_y[i] + 10'd1 : smith_y[i] - 10'd1;
                                end
                                smith_alt_x = smith_try_x;
                                smith_alt_y = smith_y[i];
                                if (slot3_rect_walkable(smith_try_x, smith_try_y, NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                                    smith_x[i] <= smith_try_x;
                                    smith_y[i] <= smith_try_y;
                                end else if (slot3_rect_walkable(smith_alt_x, smith_alt_y, NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                                    smith_x[i] <= smith_alt_x;
                                end else if (slot3_rect_walkable(smith_x[i], smith_try_y, NPC_SIZE, NPC_SIZE, map_seed, level)) begin
                                    smith_y[i] <= smith_try_y;
                                end
                            end
                        end
                    end

                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < smith_active && slot3_rect_overlap(neo_x, neo_y, HERO_SIZE, HERO_SIZE,
                                                                   smith_x[i], smith_y[i], NPC_SIZE, NPC_SIZE)) begin
                            state <= ST_LOSE;
                        end
                        if (i < smith_active && shot_active &&
                            slot3_rect_overlap(shot_x, shot_y, 10'd4, 10'd4,
                                               smith_x[i], smith_y[i], NPC_SIZE, NPC_SIZE)) begin
                            smith_x[i] <= 10'd700;
                            smith_y[i] <= 10'd520;
                            shot_active <= 1'b0;
                        end
                        if (i < smith_active && bomb_active && bomb_timer == 8'd1 &&
                            slot3_rect_overlap((bomb_x > 10'd24) ? bomb_x - 10'd24 : 10'd0,
                                               (bomb_y > 10'd24) ? bomb_y - 10'd24 : 10'd0,
                                               10'd64, 10'd64,
                                               smith_x[i], smith_y[i], NPC_SIZE, NPC_SIZE)) begin
                            smith_x[i] <= 10'd700;
                            smith_y[i] <= 10'd520;
                        end
                    end
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < smith_active && smith_active < smith_count &&
                            slot3_rect_overlap(smith_x[i], smith_y[i], NPC_SIZE, NPC_SIZE,
                                               npc_x[smith_active[2:0]], npc_y[smith_active[2:0]], NPC_SIZE, NPC_SIZE)) begin
                            smith_x[smith_active[2:0]] <= npc_x[smith_active[2:0]];
                            smith_y[smith_active[2:0]] <= npc_y[smith_active[2:0]];
                            smith_active <= smith_active + 5'd1;
                        end
                    end
                end
                ST_PILL: begin
                    if (input_left) begin
                        pill_choice <= 1'b0;
                    end else if (input_right) begin
                        pill_choice <= 1'b1;
                    end
                    if (confirm_pulse) begin
                        if (pill_choice == 1'b0) begin
                            state <= ST_WIN;
                        end else begin
                            slot3_start_level(level + 4'd1, lfsr ^ {level, 12'hA51});
                            state <= ST_PLAY;
                        end
                    end
                end
                ST_WIN: begin
                    if (confirm_pulse || esc_pulse) begin
                        state <= ST_START;
                    end
                end
                ST_LOSE: begin
                    if (confirm_pulse || esc_pulse) begin
                        state <= ST_START;
                    end
                end
                ST_EXIT: begin
                    if (confirm_pulse || esc_pulse) begin
                        state <= ST_START;
                    end
                end
                default: begin
                    state <= ST_START;
                end
            endcase
        end
    end

    wire neo_on = display_active &&
                  (pixel_x >= neo_x) && (pixel_x < neo_x + HERO_SIZE) &&
                  (pixel_y >= neo_y) && (pixel_y < neo_y + HERO_SIZE);
    wire [3:0] neo_lx = pixel_x - neo_x;
    wire [3:0] neo_ly = pixel_y - neo_y;
    wire phone_on = display_active &&
                    (pixel_x >= phone_x) && (pixel_x < phone_x + PHONE_SIZE) &&
                    (pixel_y >= phone_y) && (pixel_y < phone_y + PHONE_SIZE);
    wire red_on = display_active &&
                  (pixel_x >= red_x) && (pixel_x < red_x + NPC_SIZE) &&
                  (pixel_y >= red_y) && (pixel_y < red_y + NPC_SIZE);
    wire trinity_on = display_active &&
                      (pixel_x >= trinity_x) && (pixel_x < trinity_x + NPC_SIZE) &&
                      (pixel_y >= trinity_y) && (pixel_y < trinity_y + NPC_SIZE);
    wire shot_on = display_active && shot_active &&
                   (pixel_x >= shot_x) && (pixel_x < shot_x + 10'd4) &&
                   (pixel_y >= shot_y) && (pixel_y < shot_y + 10'd4);
    wire bomb_on = display_active && bomb_active &&
                   (pixel_x >= bomb_x) && (pixel_x < bomb_x + 10'd12) &&
                   (pixel_y >= bomb_y) && (pixel_y < bomb_y + 10'd12);
    wire gun_on = display_active && (ammo == 6'd0) &&
                  (pixel_x >= 10'd104) && (pixel_x < 10'd118) &&
                  (pixel_y >= 10'd392) && (pixel_y < 10'd406);
    wire charge_on = display_active && (charges == 2'd0) &&
                     (pixel_x >= 10'd520) && (pixel_x < 10'd534) &&
                     (pixel_y >= 10'd104) && (pixel_y < 10'd118);

    reg npc_on;
    reg smith_on;
    reg [3:0] npc_lx;
    reg [3:0] npc_ly;
    reg [3:0] smith_lx;
    reg [3:0] smith_ly;
    reg rain_on;
    reg [3:0] text_r;
    reg [3:0] text_g;
    reg [3:0] text_b;
    reg text_on;

    always @(*) begin
        npc_on = 1'b0;
        npc_lx = 4'd0;
        npc_ly = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!npc_on && display_active &&
                (pixel_x >= npc_x[i]) && (pixel_x < npc_x[i] + NPC_SIZE) &&
                (pixel_y >= npc_y[i]) && (pixel_y < npc_y[i] + NPC_SIZE)) begin
                npc_on = 1'b1;
                npc_lx = pixel_x - npc_x[i];
                npc_ly = pixel_y - npc_y[i];
            end
        end
    end

    always @(*) begin
        smith_on = 1'b0;
        smith_lx = 4'd0;
        smith_ly = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (!smith_on && (i < smith_active) && display_active &&
                (pixel_x >= smith_x[i]) && (pixel_x < smith_x[i] + NPC_SIZE) &&
                (pixel_y >= smith_y[i]) && (pixel_y < smith_y[i] + NPC_SIZE)) begin
                smith_on = 1'b1;
                smith_lx = pixel_x - smith_x[i];
                smith_ly = pixel_y - smith_y[i];
            end
        end
    end

    always @(*) begin
        rain_on = ((rain_sum[4:0] < 5'd12) &&
                   (((pixel_x[9:3] ^ pixel_y[8:2] ^ rain_phase[7:1]) & 7'd15) == 7'd0));
    end

    always @(*) begin
        text_on = 1'b0;
        text_r = 4'h0;
        text_g = 4'hF;
        text_b = 4'h4;
        if (state == ST_START) begin
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd160, 10'd100, 4'd4, 8'd0)) begin
                text_on = 1'b1;
            end
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd224, 10'd260, 4'd2, 8'd1)) begin
                text_on = 1'b1;
                text_g = start_choice == 2'd0 ? 4'hF : 4'h6;
            end
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd232, 10'd320, 4'd2, 8'd2)) begin
                text_on = 1'b1;
                text_g = start_choice == 2'd1 ? 4'hF : 4'h6;
            end
        end else if (state == ST_WIN) begin
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd184, 10'd196, 4'd4, 8'd3)) begin
                text_on = 1'b1;
            end
        end else if (state == ST_LOSE) begin
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd176, 10'd196, 4'd4, 8'd4)) begin
                text_on = 1'b1;
                text_r = 4'hF;
                text_g = 4'h2;
                text_b = 4'h2;
            end
        end else if (state == ST_EXIT) begin
            if (slot3_text_pixel(pixel_x, pixel_y, 10'd176, 10'd196, 4'd4, 8'd5)) begin
                text_on = 1'b1;
            end
        end
    end

    always @(*) begin
        if (!display_active || !selected) begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end else if (state == ST_START || state == ST_WIN || state == ST_LOSE || state == ST_EXIT) begin
            vga_r = 4'h0;
            vga_g = rain_on ? 4'h8 : 4'h1;
            vga_b = 4'h0;
            if (text_on) begin
                vga_r = text_r;
                vga_g = text_g;
                vga_b = text_b;
            end
            if (state == ST_START &&
                (((start_choice == 2'd0) && (pixel_x >= 10'd204) && (pixel_x < 10'd436) && (pixel_y >= 10'd246) && (pixel_y < 10'd296)) ||
                 ((start_choice == 2'd1) && (pixel_x >= 10'd204) && (pixel_x < 10'd436) && (pixel_y >= 10'd306) && (pixel_y < 10'd356)) ||
                 ((start_choice == 2'd2) && (pixel_x >= 10'd204) && (pixel_x < 10'd436) && (pixel_y >= 10'd366) && (pixel_y < 10'd416)))) begin
                if (pixel_x[2] ^ pixel_y[2]) begin
                    vga_r = 4'h0;
                    vga_g = 4'hF;
                    vga_b = 4'h4;
                end
            end
            if (state == ST_START && start_choice == 2'd1 &&
                pixel_x >= (10'd280 + {start_difficulty, 5'd0}) &&
                pixel_x <  (10'd296 + {start_difficulty, 5'd0}) &&
                pixel_y >= 10'd325 && pixel_y < 10'd337) begin
                vga_r = 4'hF;
                vga_g = 4'hF;
                vga_b = 4'h0;
            end
        end else if (state == ST_PILL) begin
            vga_r = 4'h0;
            vga_g = 4'h1;
            vga_b = 4'h0;
            if ((pixel_x > 10'd250 && pixel_x < 10'd390 && pixel_y > 10'd94 && pixel_y < 10'd206) ||
                (pixel_x > 10'd190 && pixel_x < 10'd450 && pixel_y > 10'd206 && pixel_y < 10'd260)) begin
                vga_r = 4'h5;
                vga_g = 4'h3;
                vga_b = 4'h2;
            end
            if ((pixel_x >= 10'd210 && pixel_x < 10'd286 && pixel_y >= 10'd300 && pixel_y < 10'd350)) begin
                vga_r = 4'hC;
                vga_g = 4'h1;
                vga_b = 4'h1;
            end
            if ((pixel_x >= 10'd354 && pixel_x < 10'd430 && pixel_y >= 10'd300 && pixel_y < 10'd350)) begin
                vga_r = 4'h1;
                vga_g = 4'h4;
                vga_b = 4'hD;
            end
            if ((pill_choice == 1'b0 && pixel_x >= 10'd202 && pixel_x < 10'd294 && pixel_y >= 10'd292 && pixel_y < 10'd358) ||
                (pill_choice == 1'b1 && pixel_x >= 10'd346 && pixel_x < 10'd438 && pixel_y >= 10'd292 && pixel_y < 10'd358)) begin
                if (pixel_x[2] ^ pixel_y[2]) begin
                    vga_r = 4'hF;
                    vga_g = 4'hF;
                    vga_b = 4'hF;
                end
            end
            if ((pixel_x >= 10'd250 && pixel_x < 10'd275 && pixel_y >= 10'd146 && pixel_y < 10'd198) ||
                (pixel_x >= 10'd365 && pixel_x < 10'd390 && pixel_y >= 10'd146 && pixel_y < 10'd198)) begin
                vga_r = 4'hE;
                vga_g = 4'hC;
                vga_b = 4'h9;
            end
        end else begin
            if (bridge_tile) begin
                vga_r = 4'h8;
                vga_g = 4'h5;
                vga_b = 4'h2;
            end else begin
            case (tile_type)
                TILE_RIVER: begin
                    vga_r = 4'h0;
                    vga_g = 4'h4;
                    vga_b = 4'hC;
                end
                TILE_BUILD: begin
                    vga_r = (local_x[3] ^ local_y[3]) ? 4'h5 : 4'h2;
                    vga_g = (local_x[3] ^ local_y[3]) ? 4'h7 : 4'h3;
                    vga_b = (local_x[3] ^ local_y[3]) ? 4'h8 : 4'h4;
                end
                TILE_TREE: begin
                    vga_r = local_y > 4'd10 ? 4'h6 : 4'h0;
                    vga_g = local_y > 4'd10 ? 4'h3 : 4'h8;
                    vga_b = 4'h1;
                end
                default: begin
                    if (local_x == 4'd0 || local_y == 4'd0) begin
                        vga_r = 4'h1;
                        vga_g = 4'h1;
                        vga_b = 4'h1;
                    end else begin
                        vga_r = 4'h2;
                        vga_g = 4'h2;
                        vga_b = 4'h2;
                    end
                end
            endcase
            end

            if (phone_on) begin
                vga_r = 4'h0;
                vga_g = 4'hC;
                vga_b = 4'hF;
            end
            if (gun_on) begin
                vga_r = 4'hD;
                vga_g = 4'hF;
                vga_b = 4'hD;
            end
            if (charge_on) begin
                vga_r = 4'hF;
                vga_g = 4'h7;
                vga_b = 4'h1;
            end
            if (bomb_on) begin
                vga_r = bomb_timer[3] ? 4'hF : 4'h8;
                vga_g = bomb_timer[3] ? 4'hE : 4'h3;
                vga_b = 4'h0;
            end
            if (shot_on) begin
                vga_r = 4'hF;
                vga_g = 4'hF;
                vga_b = 4'h4;
            end
            if (npc_on && !smith_on) begin
                vga_r = (npc_ly < 4'd4) ? 4'hE : 4'h4;
                vga_g = (npc_ly < 4'd4) ? 4'hB : 4'h5;
                vga_b = (npc_lx[1] ^ npc_ly[1]) ? 4'h6 : 4'h3;
            end
            if (red_on) begin
                vga_r = 4'hF;
                vga_g = (red_on && local_y < 4'd3) ? 4'hC : 4'h1;
                vga_b = 4'h2;
            end
            if (trinity_on) begin
                vga_r = 4'h1;
                vga_g = 4'hE;
                vga_b = 4'h9;
            end
            if (smith_on) begin
                vga_r = (smith_lx == 4'd5 || smith_lx == 4'd6) ? 4'hE : 4'h0;
                vga_g = (smith_lx == 4'd5 || smith_lx == 4'd6) ? 4'hE : 4'h0;
                vga_b = (smith_lx == 4'd5 || smith_lx == 4'd6) ? 4'hE : 4'h0;
            end
            if (neo_on) begin
                if (neo_ly < 4'd3) begin
                    vga_r = 4'h0;
                    vga_g = 4'h0;
                    vga_b = 4'h0;
                end else if (neo_lx > 4'd4 && neo_lx < 4'd9 && neo_ly > 4'd4 && neo_ly < 4'd12) begin
                    vga_r = 4'h1;
                    vga_g = 4'h8;
                    vga_b = 4'h2;
                end else begin
                    vga_r = 4'hE;
                    vga_g = 4'hC;
                    vga_b = 4'h9;
                end
            end
            if (bullet_time_active && ((pixel_x[3:0] == 4'd0) || (pixel_y[3:0] == 4'd0))) begin
                vga_g = 4'hF;
            end
            if (attract_timer != 8'd0 && frame_count[3]) begin
                vga_r = vga_r ^ 4'h7;
                vga_g = vga_g >> 1;
                vga_b = vga_b >> 1;
            end
        end
    end

    function slot3_text_pixel;
        input [9:0] px;
        input [9:0] py;
        input [9:0] ox;
        input [9:0] oy;
        input [3:0] scale;
        input [7:0] msg;
        reg [9:0] lx;
        reg [9:0] ly;
        reg [6:0] col;
        reg [4:0] row;
        begin
            lx = px - ox;
            ly = py - oy;
            col = scale[2] ? lx[9:2] : lx[9:1];
            row = scale[2] ? ly[9:2] : ly[9:1];
            slot3_text_pixel = 1'b0;
            if (px >= ox && py >= oy && row < 5'd7) begin
                case (msg)
                    8'd0: slot3_text_pixel = slot3_word_matrix(col, row);
                    8'd1: slot3_text_pixel = slot3_word_start(col, row);
                    8'd2: slot3_text_pixel = slot3_word_exit(col, row);
                    8'd3: slot3_text_pixel = slot3_word_win(col, row);
                    8'd4: slot3_text_pixel = slot3_word_lose(col, row);
                    8'd5: slot3_text_pixel = slot3_word_exit(col, row);
                    default: slot3_text_pixel = 1'b0;
                endcase
            end
        end
    endfunction

    function slot3_char_pixel;
        input [4:0] ch;
        input [2:0] x;
        input [2:0] y;
        reg [4:0] bits;
        begin
            bits = 5'b00000;
            case (ch)
                5'd0: case (y) 3'd0: bits=5'b11110; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11110; 3'd4: bits=5'b10000; 3'd5: bits=5'b10000; 3'd6: bits=5'b10000; default: bits=5'b00000; endcase
                5'd1: case (y) 3'd0: bits=5'b01110; 3'd1: bits=5'b10001; 3'd2: bits=5'b10000; 3'd3: bits=5'b01110; 3'd4: bits=5'b00001; 3'd5: bits=5'b10001; 3'd6: bits=5'b01110; default: bits=5'b00000; endcase
                5'd2: case (y) 3'd0: bits=5'b11111; 3'd1: bits=5'b00100; 3'd2: bits=5'b00100; 3'd3: bits=5'b00100; 3'd4: bits=5'b00100; 3'd5: bits=5'b00100; 3'd6: bits=5'b00100; default: bits=5'b00000; endcase
                5'd3: case (y) 3'd0: bits=5'b10001; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11111; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b10001; default: bits=5'b00000; endcase
                5'd4: case (y) 3'd0: bits=5'b11110; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b11110; 3'd4: bits=5'b10100; 3'd5: bits=5'b10010; 3'd6: bits=5'b10001; default: bits=5'b00000; endcase
                5'd5: case (y) 3'd0: bits=5'b10001; 3'd1: bits=5'b11011; 3'd2: bits=5'b10101; 3'd3: bits=5'b10101; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b10001; default: bits=5'b00000; endcase
                5'd6: case (y) 3'd0: bits=5'b10001; 3'd1: bits=5'b11001; 3'd2: bits=5'b10101; 3'd3: bits=5'b10011; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b10001; default: bits=5'b00000; endcase
                5'd7: case (y) 3'd0: bits=5'b10001; 3'd1: bits=5'b01010; 3'd2: bits=5'b00100; 3'd3: bits=5'b00100; 3'd4: bits=5'b01010; 3'd5: bits=5'b10001; 3'd6: bits=5'b10001; default: bits=5'b00000; endcase
                5'd8: case (y) 3'd0: bits=5'b01110; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b10001; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b01110; default: bits=5'b00000; endcase
                5'd9: case (y) 3'd0: bits=5'b11111; 3'd1: bits=5'b10000; 3'd2: bits=5'b10000; 3'd3: bits=5'b11110; 3'd4: bits=5'b10000; 3'd5: bits=5'b10000; 3'd6: bits=5'b11111; default: bits=5'b00000; endcase
                5'd10: case (y) 3'd0: bits=5'b10001; 3'd1: bits=5'b10001; 3'd2: bits=5'b10001; 3'd3: bits=5'b10001; 3'd4: bits=5'b10001; 3'd5: bits=5'b10001; 3'd6: bits=5'b01110; default: bits=5'b00000; endcase
                5'd11: case (y) 3'd0: bits=5'b10000; 3'd1: bits=5'b10000; 3'd2: bits=5'b10000; 3'd3: bits=5'b10000; 3'd4: bits=5'b10000; 3'd5: bits=5'b10000; 3'd6: bits=5'b11111; default: bits=5'b00000; endcase
                5'd12: case (y) 3'd0: bits=5'b11111; 3'd1: bits=5'b00100; 3'd2: bits=5'b00100; 3'd3: bits=5'b00100; 3'd4: bits=5'b00100; 3'd5: bits=5'b00100; 3'd6: bits=5'b11111; default: bits=5'b00000; endcase
                5'd13: case (y) 3'd0: bits=5'b11111; 3'd1: bits=5'b10000; 3'd2: bits=5'b10000; 3'd3: bits=5'b11110; 3'd4: bits=5'b10000; 3'd5: bits=5'b10000; 3'd6: bits=5'b10000; default: bits=5'b00000; endcase
                default: bits = 5'b00000;
            endcase
            if (x < 3'd5) begin
                slot3_char_pixel = bits[3'd4 - x];
            end else begin
                slot3_char_pixel = 1'b0;
            end
        end
    endfunction

    function slot3_word_matrix;
        input [6:0] col;
        input [4:0] row;
        reg [2:0] cx;
        reg [4:0] ch;
        begin
            cx = col % 7'd6;
            ch = 5'd31;
            case (col / 7'd6)
                7'd0: ch = 5'd5;
                7'd1: ch = 5'd3;
                7'd2: ch = 5'd2;
                7'd3: ch = 5'd4;
                7'd4: ch = 5'd12;
                7'd5: ch = 5'd7;
                default: ch = 5'd31;
            endcase
            slot3_word_matrix = (cx < 3'd5) && slot3_char_pixel(ch, cx, row[2:0]);
        end
    endfunction

    function slot3_word_start;
        input [6:0] col;
        input [4:0] row;
        reg [2:0] cx;
        reg [4:0] ch;
        begin
            cx = col % 7'd6;
            ch = 5'd31;
            case (col / 7'd6)
                7'd0: ch = 5'd1;
                7'd1: ch = 5'd2;
                7'd2: ch = 5'd3;
                7'd3: ch = 5'd4;
                7'd4: ch = 5'd2;
                default: ch = 5'd31;
            endcase
            slot3_word_start = (cx < 3'd5) && slot3_char_pixel(ch, cx, row[2:0]);
        end
    endfunction

    function slot3_word_exit;
        input [6:0] col;
        input [4:0] row;
        reg [2:0] cx;
        reg [4:0] ch;
        begin
            cx = col % 7'd6;
            ch = 5'd31;
            case (col / 7'd6)
                7'd0: ch = 5'd9;
                7'd1: ch = 5'd7;
                7'd2: ch = 5'd12;
                7'd3: ch = 5'd2;
                default: ch = 5'd31;
            endcase
            slot3_word_exit = (cx < 3'd5) && slot3_char_pixel(ch, cx, row[2:0]);
        end
    endfunction

    function slot3_word_win;
        input [6:0] col;
        input [4:0] row;
        reg [2:0] cx;
        reg [4:0] ch;
        begin
            cx = col % 7'd6;
            ch = 5'd31;
            case (col / 7'd6)
                7'd0: ch = 5'd6;
                7'd1: ch = 5'd9;
                7'd2: ch = 5'd8;
                default: ch = 5'd31;
            endcase
            slot3_word_win = (cx < 3'd5) && slot3_char_pixel(ch, cx, row[2:0]);
        end
    endfunction

    function slot3_word_lose;
        input [6:0] col;
        input [4:0] row;
        reg [2:0] cx;
        reg [4:0] ch;
        begin
            cx = col % 7'd6;
            ch = 5'd31;
            case (col / 7'd6)
                7'd0: ch = 5'd11;
                7'd1: ch = 5'd8;
                7'd2: ch = 5'd1;
                7'd3: ch = 5'd9;
                default: ch = 5'd31;
            endcase
            slot3_word_lose = (cx < 3'd5) && slot3_char_pixel(ch, cx, row[2:0]);
        end
    endfunction

endmodule
