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

    localparam integer CELL = 20;
    localparam integer SCREEN_W = 640;
    localparam integer SCREEN_H = 480;
    localparam integer PLAYER_W = 14;
    localparam integer PLAYER_H = 18;
    localparam signed [5:0] GRAVITY = 6'sd1;
    localparam signed [5:0] MAX_FALL = 6'sd8;
    localparam signed [5:0] JUMP_VEL = -6'sd16;
    localparam integer MOVE_STEP = 3;
    localparam integer COLLIDE_INSET_X = 4;
    localparam integer COLLIDE_INSET_Y = 4;

    localparam [3:0] TILE_EMPTY      = 4'd0;
    localparam [3:0] TILE_WALL       = 4'd1;
    localparam [3:0] TILE_FIRE       = 4'd2;
    localparam [3:0] TILE_WATER      = 4'd3;
    localparam [3:0] TILE_POISON     = 4'd4;
    localparam [3:0] TILE_FIRE_GEM   = 4'd5;
    localparam [3:0] TILE_WATER_GEM  = 4'd6;
    localparam [3:0] TILE_FIRE_DOOR  = 4'd7;
    localparam [3:0] TILE_WATER_DOOR = 4'd8;
    localparam [3:0] TILE_BUTTON     = 4'd9;
    localparam [3:0] TILE_GATE       = 4'd10;

    localparam [3:0] PHYS_IDLE           = 4'd0;
    localparam [3:0] PHYS_FIRE_X_TEST    = 4'd1;
    localparam [3:0] PHYS_FIRE_X_EVAL    = 4'd2;
    localparam [3:0] PHYS_FIRE_X_APPLY   = 4'd3;
    localparam [3:0] PHYS_WATER_X_TEST   = 4'd4;
    localparam [3:0] PHYS_WATER_X_EVAL   = 4'd5;
    localparam [3:0] PHYS_WATER_X_APPLY  = 4'd6;
    localparam [3:0] PHYS_FIRE_Y_TEST    = 4'd7;
    localparam [3:0] PHYS_FIRE_Y_EVAL    = 4'd8;
    localparam [3:0] PHYS_FIRE_Y_APPLY   = 4'd9;
    localparam [3:0] PHYS_WATER_Y_TEST   = 4'd10;
    localparam [3:0] PHYS_WATER_Y_EVAL   = 4'd11;
    localparam [3:0] PHYS_WATER_Y_APPLY  = 4'd12;

    function [11:0] slot4_tile_addr;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        begin
            slot4_tile_addr = {7'd0, tx} + ({2'd0, ty, 5'd0});
            if (lvl == 2'd1)
                slot4_tile_addr = slot4_tile_addr + 12'd768;
            else if (lvl != 2'd0)
                slot4_tile_addr = slot4_tile_addr + 12'd1536;
        end
    endfunction

    (* rom_style = "distributed" *) reg [3:0] slot4_tile_rom [0:2303];

    task slot4_set_tile;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        input [3:0] tile;
        begin
            slot4_tile_rom[slot4_tile_addr(lvl, tx, ty)] = tile;
        end
    endtask

    task slot4_fill_hspan;
        input [1:0] lvl;
        input [4:0] ty;
        input [4:0] x0;
        input [4:0] x1;
        input [3:0] tile;
        integer fill_x;
        begin
            for (fill_x = x0; fill_x <= x1; fill_x = fill_x + 1)
                slot4_set_tile(lvl, fill_x[4:0], ty, tile);
        end
    endtask

    task slot4_fill_vspan;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] y0;
        input [4:0] y1;
        input [3:0] tile;
        integer fill_y;
        begin
            for (fill_y = y0; fill_y <= y1; fill_y = fill_y + 1)
                slot4_set_tile(lvl, tx, fill_y[4:0], tile);
        end
    endtask

    integer init_i;
    integer init_lvl;
    integer init_pos;
    initial begin
        for (init_i = 0; init_i < 2304; init_i = init_i + 1)
            slot4_tile_rom[init_i] = TILE_EMPTY;

        for (init_lvl = 0; init_lvl < 3; init_lvl = init_lvl + 1) begin
            for (init_pos = 0; init_pos < 32; init_pos = init_pos + 1) begin
                slot4_set_tile(init_lvl[1:0], init_pos[4:0], 5'd0, TILE_WALL);
                slot4_set_tile(init_lvl[1:0], init_pos[4:0], 5'd23, TILE_WALL);
            end
            for (init_pos = 0; init_pos < 24; init_pos = init_pos + 1) begin
                slot4_set_tile(init_lvl[1:0], 5'd0, init_pos[4:0], TILE_WALL);
                slot4_set_tile(init_lvl[1:0], 5'd31, init_pos[4:0], TILE_WALL);
            end
        end

        slot4_fill_hspan(2'd0, 5'd4, 5'd6, 5'd17, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd4, 5'd19, 5'd25, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd7, 5'd2, 5'd6, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd7, 5'd25, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd9, 5'd8, 5'd11, TILE_FIRE);
        slot4_fill_hspan(2'd0, 5'd9, 5'd20, 5'd23, TILE_WATER);
        slot4_fill_hspan(2'd0, 5'd10, 5'd6, 5'd13, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd10, 5'd18, 5'd25, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd13, 5'd4, 5'd9, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd13, 5'd22, 5'd27, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd15, 5'd14, 5'd15, TILE_POISON);
        slot4_fill_hspan(2'd0, 5'd16, 5'd12, 5'd19, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd18, 5'd4, 5'd7, TILE_WALL);
        slot4_fill_hspan(2'd0, 5'd18, 5'd24, 5'd27, TILE_WALL);
        slot4_set_tile(2'd0, 5'd14, 5'd3, TILE_FIRE_DOOR);
        slot4_set_tile(2'd0, 5'd16, 5'd3, TILE_WATER_DOOR);
        slot4_set_tile(2'd0, 5'd9, 5'd3, TILE_FIRE_GEM);
        slot4_set_tile(2'd0, 5'd11, 5'd12, TILE_FIRE_GEM);
        slot4_set_tile(2'd0, 5'd22, 5'd3, TILE_WATER_GEM);
        slot4_set_tile(2'd0, 5'd20, 5'd12, TILE_WATER_GEM);

        slot4_fill_hspan(2'd1, 5'd6, 5'd8, 5'd24, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd9, 5'd2, 5'd6, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd9, 5'd25, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd10, 5'd4, 5'd12, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd10, 5'd19, 5'd27, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd12, 5'd9, 5'd12, TILE_FIRE);
        slot4_fill_hspan(2'd1, 5'd12, 5'd19, 5'd22, TILE_WATER);
        slot4_fill_hspan(2'd1, 5'd13, 5'd14, 5'd17, TILE_POISON);
        slot4_fill_hspan(2'd1, 5'd14, 5'd10, 5'd21, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd16, 5'd5, 5'd10, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd16, 5'd21, 5'd26, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd17, 5'd4, 5'd7, TILE_FIRE);
        slot4_fill_hspan(2'd1, 5'd17, 5'd24, 5'd27, TILE_WATER);
        slot4_fill_hspan(2'd1, 5'd18, 5'd2, 5'd9, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd18, 5'd12, 5'd19, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd18, 5'd22, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd1, 5'd20, 5'd11, 5'd13, TILE_POISON);
        slot4_fill_hspan(2'd1, 5'd20, 5'd18, 5'd20, TILE_POISON);
        slot4_fill_vspan(2'd1, 5'd15, 5'd10, 5'd14, TILE_GATE);
        slot4_set_tile(2'd1, 5'd15, 5'd17, TILE_BUTTON);
        slot4_set_tile(2'd1, 5'd11, 5'd5, TILE_FIRE_DOOR);
        slot4_set_tile(2'd1, 5'd22, 5'd5, TILE_WATER_DOOR);
        slot4_set_tile(2'd1, 5'd6, 5'd17, TILE_FIRE_GEM);
        slot4_set_tile(2'd1, 5'd12, 5'd9, TILE_FIRE_GEM);
        slot4_set_tile(2'd1, 5'd25, 5'd17, TILE_WATER_GEM);
        slot4_set_tile(2'd1, 5'd20, 5'd9, TILE_WATER_GEM);

        slot4_set_tile(2'd2, 5'd15, 5'd5, TILE_POISON);
        slot4_fill_hspan(2'd2, 5'd6, 5'd4, 5'd13, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd6, 5'd19, 5'd28, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd9, 5'd2, 5'd5, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd9, 5'd26, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd10, 5'd2, 5'd6, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd10, 5'd10, 5'd15, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd10, 5'd17, 5'd22, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd10, 5'd26, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd12, 5'd7, 5'd10, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd12, 5'd21, 5'd24, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd13, 5'd10, 5'd13, TILE_FIRE);
        slot4_fill_hspan(2'd2, 5'd13, 5'd18, 5'd21, TILE_WATER);
        slot4_fill_hspan(2'd2, 5'd13, 5'd14, 5'd17, TILE_POISON);
        slot4_fill_hspan(2'd2, 5'd14, 5'd4, 5'd11, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd14, 5'd20, 5'd27, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd16, 5'd13, 5'd18, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd17, 5'd4, 5'd5, TILE_POISON);
        slot4_fill_hspan(2'd2, 5'd17, 5'd24, 5'd25, TILE_POISON);
        slot4_fill_hspan(2'd2, 5'd18, 5'd2, 5'd9, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd18, 5'd22, 5'd29, TILE_WALL);
        slot4_fill_hspan(2'd2, 5'd20, 5'd12, 5'd19, TILE_WALL);
        slot4_fill_vspan(2'd2, 5'd8, 5'd10, 5'd14, TILE_GATE);
        slot4_fill_vspan(2'd2, 5'd24, 5'd10, 5'd14, TILE_GATE);
        slot4_set_tile(2'd2, 5'd5, 5'd17, TILE_BUTTON);
        slot4_set_tile(2'd2, 5'd26, 5'd17, TILE_BUTTON);
        slot4_set_tile(2'd2, 5'd9, 5'd5, TILE_FIRE_DOOR);
        slot4_set_tile(2'd2, 5'd22, 5'd5, TILE_WATER_DOOR);
        slot4_set_tile(2'd2, 5'd5, 5'd5, TILE_FIRE_GEM);
        slot4_set_tile(2'd2, 5'd21, 5'd13, TILE_FIRE_GEM);
        slot4_set_tile(2'd2, 5'd26, 5'd5, TILE_WATER_GEM);
        slot4_set_tile(2'd2, 5'd10, 5'd13, TILE_WATER_GEM);
    end

    wire fire_left_key;
    wire fire_right_key;
    wire fire_jump_key;
    wire water_left_key;
    wire water_right_key;
    wire water_jump_key;
    wire water_down_key;

    reg [1:0] level;
    reg won;
    reg [9:0] fire_x;
    reg [9:0] fire_y;
    reg [9:0] water_x;
    reg [9:0] water_y;
    reg signed [5:0] fire_vy;
    reg signed [5:0] water_vy;
    reg [3:0] fire_gems;
    reg [3:0] water_gems;
    reg [1:0] button_mask;
    reg [23:0] frame_counter;
    reg frame_tick_q;
    reg status_eval_q;
    reg status_apply_q;
    reg frame_step_q;
    reg [3:0] phys_state;

    reg btn_u_sync0;
    reg btn_u_sync1;
    reg btn_d_sync0;
    reg btn_d_sync1;
    reg btn_l_sync0;
    reg btn_l_sync1;
    reg btn_r_sync0;
    reg btn_r_sync1;
    reg btn_c_sync0;
    reg btn_c_sync1;
    reg sw0_sync0;
    reg sw0_sync1;
    reg sw1_sync0;
    reg sw1_sync1;
    reg sw2_sync0;
    reg sw2_sync1;

    reg btn_u_q;
    reg btn_d_q;
    reg btn_l_q;
    reg btn_r_q;
    reg btn_c_q;
    reg fire_left_key_q;
    reg fire_right_key_q;
    reg fire_jump_key_q;
    reg water_left_key_q;
    reg water_right_key_q;
    reg water_jump_key_q;
    reg water_down_key_q;
    reg sw0_q;
    reg sw1_q;
    reg sw2_q;
    reg gate_open_q;
    reg fire_grounded_q;
    reg water_grounded_q;
    reg [1:0] fire_pick_mask_q;
    reg [1:0] water_pick_mask_q;
    reg [1:0] button_pick_mask_q;
    reg level_complete_q;
    reg level_failed_q;

    reg [4:0] cell_x;
    reg [4:0] cell_y;
    reg [4:0] local_x;
    reg [4:0] local_y;
    reg [3:0] draw_tile;
    reg [3:0] render_r;
    reg [3:0] render_g;
    reg [3:0] render_b;
    reg [6:0] seg_n;

    reg [9:0] phys_x_candidate;
    reg signed [11:0] phys_y_candidate;
    reg signed [5:0] phys_vy_candidate;
    reg phys_blocked_q;
    reg phys_collision_skip_q;
    reg [11:0] phys_probe_addr0_q;
    reg [11:0] phys_probe_addr1_q;
    reg phys_probe_oob0_q;
    reg phys_probe_oob1_q;
    reg status_gate_open_q;
    reg status_fire_all_gems_q;
    reg status_water_all_gems_q;
    reg gate_open_eval_q;
    reg fire_grounded_eval_q;
    reg water_grounded_eval_q;
    reg level_complete_eval_q;
    reg level_failed_eval_q;
    reg [11:0] fire_status_addr0_q;
    reg [11:0] fire_status_addr1_q;
    reg [11:0] fire_status_addr2_q;
    reg [11:0] fire_status_addr3_q;
    reg [11:0] water_status_addr0_q;
    reg [11:0] water_status_addr1_q;
    reg [11:0] water_status_addr2_q;
    reg [11:0] water_status_addr3_q;
    reg [11:0] fire_ground_addr0_q;
    reg [11:0] fire_ground_addr1_q;
    reg [11:0] water_ground_addr0_q;
    reg [11:0] water_ground_addr1_q;
    reg [1:0] next_level;

    (* keep = "true" *) reg selected_video_q;
    (* keep = "true" *) reg display_active_video_q;
    (* keep = "true" *) reg [1:0] level_video_q;
    (* keep = "true" *) reg won_video_q;
    (* keep = "true" *) reg [9:0] fire_x_video_q;
    (* keep = "true" *) reg [9:0] fire_y_video_q;
    (* keep = "true" *) reg [9:0] water_x_video_q;
    (* keep = "true" *) reg [9:0] water_y_video_q;
    (* keep = "true" *) reg [3:0] fire_gems_video_q;
    (* keep = "true" *) reg [3:0] water_gems_video_q;
    (* keep = "true" *) reg gate_open_video_q;
    (* keep = "true" *) reg [23:0] frame_counter_video_q;

    wire gate_open;
    wire fire_grounded;
    wire water_grounded;
    wire fire_left_cmd;
    wire fire_right_cmd;
    wire fire_jump_cmd;
    wire water_left_cmd;
    wire water_right_cmd;
    wire water_jump_cmd;
    wire water_down_cmd;
    wire fire_pixel;
    wire water_pixel;
    wire fire_eye;
    wire water_eye;
    wire fire_all_gems;
    wire water_all_gems;
    wire level_complete;
    wire level_failed;
    wire gate_open_now;
    wire fire_grounded_now;
    wire water_grounded_now;
    wire [1:0] fire_pick_mask_now;
    wire [1:0] water_pick_mask_now;
    wire [1:0] button_pick_mask_now;
    wire level_complete_now;
    wire level_failed_now;
    wire phys_probe_solid;
    wire [3:0] fire_status_tile0;
    wire [3:0] fire_status_tile1;
    wire [3:0] fire_status_tile2;
    wire [3:0] fire_status_tile3;
    wire [3:0] water_status_tile0;
    wire [3:0] water_status_tile1;
    wire [3:0] water_status_tile2;
    wire [3:0] water_status_tile3;
    wire [3:0] fire_ground_tile0;
    wire [3:0] fire_ground_tile1;
    wire [3:0] water_ground_tile0;
    wire [3:0] water_ground_tile1;
    wire fire_grounded_eval_now;
    wire water_grounded_eval_now;
    wire level_complete_eval_now;
    wire level_failed_eval_now;

    assign gate_open_now = (level == 2'd0) ? 1'b1 :
                       (level == 2'd1) ? button_mask[0] :
                                         (button_mask[0] | button_mask[1]);
    assign gate_open = gate_open_q;
    assign fire_grounded = fire_grounded_q;
    assign water_grounded = water_grounded_q;

    assign fire_left_cmd = fire_left_key_q | btn_l_q;
    assign fire_right_cmd = fire_right_key_q | btn_r_q;
    assign fire_jump_cmd = fire_jump_key_q | btn_u_q;
    assign water_left_cmd = water_left_key_q | btn_l_q | sw0_q;
    assign water_right_cmd = water_right_key_q | btn_r_q | sw1_q;
    assign water_jump_cmd = water_jump_key_q | btn_u_q | sw2_q;
    assign water_down_cmd = water_down_key_q | btn_d_q;

    assign fire_all_gems = (fire_gems[1:0] == 2'b11);
    assign water_all_gems = (water_gems[1:0] == 2'b11);
    assign fire_status_tile0 = slot4_tile_rom[fire_status_addr0_q];
    assign fire_status_tile1 = slot4_tile_rom[fire_status_addr1_q];
    assign fire_status_tile2 = slot4_tile_rom[fire_status_addr2_q];
    assign fire_status_tile3 = slot4_tile_rom[fire_status_addr3_q];
    assign water_status_tile0 = slot4_tile_rom[water_status_addr0_q];
    assign water_status_tile1 = slot4_tile_rom[water_status_addr1_q];
    assign water_status_tile2 = slot4_tile_rom[water_status_addr2_q];
    assign water_status_tile3 = slot4_tile_rom[water_status_addr3_q];
    assign fire_ground_tile0 = slot4_tile_rom[fire_ground_addr0_q];
    assign fire_ground_tile1 = slot4_tile_rom[fire_ground_addr1_q];
    assign water_ground_tile0 = slot4_tile_rom[water_ground_addr0_q];
    assign water_ground_tile1 = slot4_tile_rom[water_ground_addr1_q];
    assign level_complete_eval_now = status_fire_all_gems_q && status_water_all_gems_q &&
                            ((fire_status_tile0 == TILE_FIRE_DOOR) ||
                             (fire_status_tile1 == TILE_FIRE_DOOR) ||
                             (fire_status_tile2 == TILE_FIRE_DOOR) ||
                             (fire_status_tile3 == TILE_FIRE_DOOR)) &&
                            ((water_status_tile0 == TILE_WATER_DOOR) ||
                             (water_status_tile1 == TILE_WATER_DOOR) ||
                             (water_status_tile2 == TILE_WATER_DOOR) ||
                             (water_status_tile3 == TILE_WATER_DOOR));
    assign level_failed_eval_now = (fire_status_tile0 == TILE_WATER) ||
                          (fire_status_tile1 == TILE_WATER) ||
                          (fire_status_tile2 == TILE_WATER) ||
                          (fire_status_tile3 == TILE_WATER) ||
                          (fire_status_tile0 == TILE_POISON) ||
                          (fire_status_tile1 == TILE_POISON) ||
                          (fire_status_tile2 == TILE_POISON) ||
                          (fire_status_tile3 == TILE_POISON) ||
                          (water_status_tile0 == TILE_FIRE) ||
                          (water_status_tile1 == TILE_FIRE) ||
                          (water_status_tile2 == TILE_FIRE) ||
                          (water_status_tile3 == TILE_FIRE) ||
                          (water_status_tile0 == TILE_POISON) ||
                          (water_status_tile1 == TILE_POISON) ||
                          (water_status_tile2 == TILE_POISON) ||
                          (water_status_tile3 == TILE_POISON);
    assign level_complete_now = level_complete_eval_q;
    assign level_failed_now = level_failed_eval_q;
    assign level_complete = level_complete_q;
    assign level_failed = level_failed_q;
    assign fire_pick_mask_now = slot4_fire_pick_mask(level, fire_x, fire_y);
    assign water_pick_mask_now = slot4_water_pick_mask(level, water_x, water_y);
    assign button_pick_mask_now = slot4_button_pick_mask(level, fire_x, fire_y, water_x, water_y);
    assign phys_probe_solid =
        phys_probe_oob0_q || phys_probe_oob1_q ||
        slot4_is_solid_tile(slot4_tile_rom[phys_probe_addr0_q], gate_open_q) ||
        slot4_is_solid_tile(slot4_tile_rom[phys_probe_addr1_q], gate_open_q);
    assign fire_grounded_eval_now = slot4_is_solid_tile(fire_ground_tile0, status_gate_open_q) ||
                                    slot4_is_solid_tile(fire_ground_tile1, status_gate_open_q);
    assign water_grounded_eval_now = slot4_is_solid_tile(water_ground_tile0, status_gate_open_q) ||
                                     slot4_is_solid_tile(water_ground_tile1, status_gate_open_q);
    assign fire_grounded_now = fire_grounded_eval_q;
    assign water_grounded_now = water_grounded_eval_q;

    assign fire_pixel = selected_video_q && display_active_video_q && !won_video_q &&
                        (pixel_x >= fire_x_video_q) && (pixel_x < fire_x_video_q + PLAYER_W) &&
                        (pixel_y >= fire_y_video_q) && (pixel_y < fire_y_video_q + PLAYER_H);

    assign water_pixel = selected_video_q && display_active_video_q && !won_video_q &&
                         (pixel_x >= water_x_video_q) && (pixel_x < water_x_video_q + PLAYER_W) &&
                         (pixel_y >= water_y_video_q) && (pixel_y < water_y_video_q + PLAYER_H);

    assign fire_eye = fire_pixel &&
                      (pixel_x >= fire_x_video_q + 10'd9) && (pixel_x <= fire_x_video_q + 10'd11) &&
                      (pixel_y >= fire_y_video_q + 10'd5) && (pixel_y <= fire_y_video_q + 10'd7);

    assign water_eye = water_pixel &&
                       (pixel_x >= water_x_video_q + 10'd2) && (pixel_x <= water_x_video_q + 10'd4) &&
                       (pixel_y >= water_y_video_q + 10'd5) && (pixel_y <= water_y_video_q + 10'd7);

    slot4_keyboard_mapper u_slot4_keyboard_mapper (
        .clk(clk),
        .reset(reset | ~selected),
        .byte_ready(ps2_byte_ready),
        .byte_data(ps2_byte_data),
        .fire_left(fire_left_key),
        .fire_right(fire_right_key),
        .fire_jump(fire_jump_key),
        .water_left(water_left_key),
        .water_right(water_right_key),
        .water_jump(water_jump_key),
        .water_down(water_down_key)
    );

    function [9:0] slot4_fire_start_x;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_fire_start_x = 10'd43;
                2'd1: slot4_fire_start_x = 10'd43;
                default: slot4_fire_start_x = 10'd43;
            endcase
        end
    endfunction

    function [9:0] slot4_fire_start_y;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_fire_start_y = 10'd122;
                2'd1: slot4_fire_start_y = 10'd342;
                default: slot4_fire_start_y = 10'd342;
            endcase
        end
    endfunction

    function [9:0] slot4_water_start_x;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_water_start_x = 10'd543;
                2'd1: slot4_water_start_x = 10'd543;
                default: slot4_water_start_x = 10'd563;
            endcase
        end
    endfunction

    function [9:0] slot4_water_start_y;
        input [1:0] lvl;
        begin
            case (lvl)
                2'd0: slot4_water_start_y = 10'd122;
                2'd1: slot4_water_start_y = 10'd342;
                default: slot4_water_start_y = 10'd342;
            endcase
        end
    endfunction

    function slot4_is_solid_tile;
        input [3:0] tile;
        input open_gate;
        begin
            slot4_is_solid_tile = (tile == TILE_WALL) || ((tile == TILE_GATE) && !open_gate);
        end
    endfunction

    function [4:0] slot4_pixel_to_cell_x;
        input [9:0] px;
        begin
            if (px < 10'd20) slot4_pixel_to_cell_x = 5'd0;
            else if (px < 10'd40) slot4_pixel_to_cell_x = 5'd1;
            else if (px < 10'd60) slot4_pixel_to_cell_x = 5'd2;
            else if (px < 10'd80) slot4_pixel_to_cell_x = 5'd3;
            else if (px < 10'd100) slot4_pixel_to_cell_x = 5'd4;
            else if (px < 10'd120) slot4_pixel_to_cell_x = 5'd5;
            else if (px < 10'd140) slot4_pixel_to_cell_x = 5'd6;
            else if (px < 10'd160) slot4_pixel_to_cell_x = 5'd7;
            else if (px < 10'd180) slot4_pixel_to_cell_x = 5'd8;
            else if (px < 10'd200) slot4_pixel_to_cell_x = 5'd9;
            else if (px < 10'd220) slot4_pixel_to_cell_x = 5'd10;
            else if (px < 10'd240) slot4_pixel_to_cell_x = 5'd11;
            else if (px < 10'd260) slot4_pixel_to_cell_x = 5'd12;
            else if (px < 10'd280) slot4_pixel_to_cell_x = 5'd13;
            else if (px < 10'd300) slot4_pixel_to_cell_x = 5'd14;
            else if (px < 10'd320) slot4_pixel_to_cell_x = 5'd15;
            else if (px < 10'd340) slot4_pixel_to_cell_x = 5'd16;
            else if (px < 10'd360) slot4_pixel_to_cell_x = 5'd17;
            else if (px < 10'd380) slot4_pixel_to_cell_x = 5'd18;
            else if (px < 10'd400) slot4_pixel_to_cell_x = 5'd19;
            else if (px < 10'd420) slot4_pixel_to_cell_x = 5'd20;
            else if (px < 10'd440) slot4_pixel_to_cell_x = 5'd21;
            else if (px < 10'd460) slot4_pixel_to_cell_x = 5'd22;
            else if (px < 10'd480) slot4_pixel_to_cell_x = 5'd23;
            else if (px < 10'd500) slot4_pixel_to_cell_x = 5'd24;
            else if (px < 10'd520) slot4_pixel_to_cell_x = 5'd25;
            else if (px < 10'd540) slot4_pixel_to_cell_x = 5'd26;
            else if (px < 10'd560) slot4_pixel_to_cell_x = 5'd27;
            else if (px < 10'd580) slot4_pixel_to_cell_x = 5'd28;
            else if (px < 10'd600) slot4_pixel_to_cell_x = 5'd29;
            else if (px < 10'd620) slot4_pixel_to_cell_x = 5'd30;
            else slot4_pixel_to_cell_x = 5'd31;
        end
    endfunction

    function [4:0] slot4_pixel_to_cell_y;
        input [9:0] py;
        begin
            if (py < 10'd20) slot4_pixel_to_cell_y = 5'd0;
            else if (py < 10'd40) slot4_pixel_to_cell_y = 5'd1;
            else if (py < 10'd60) slot4_pixel_to_cell_y = 5'd2;
            else if (py < 10'd80) slot4_pixel_to_cell_y = 5'd3;
            else if (py < 10'd100) slot4_pixel_to_cell_y = 5'd4;
            else if (py < 10'd120) slot4_pixel_to_cell_y = 5'd5;
            else if (py < 10'd140) slot4_pixel_to_cell_y = 5'd6;
            else if (py < 10'd160) slot4_pixel_to_cell_y = 5'd7;
            else if (py < 10'd180) slot4_pixel_to_cell_y = 5'd8;
            else if (py < 10'd200) slot4_pixel_to_cell_y = 5'd9;
            else if (py < 10'd220) slot4_pixel_to_cell_y = 5'd10;
            else if (py < 10'd240) slot4_pixel_to_cell_y = 5'd11;
            else if (py < 10'd260) slot4_pixel_to_cell_y = 5'd12;
            else if (py < 10'd280) slot4_pixel_to_cell_y = 5'd13;
            else if (py < 10'd300) slot4_pixel_to_cell_y = 5'd14;
            else if (py < 10'd320) slot4_pixel_to_cell_y = 5'd15;
            else if (py < 10'd340) slot4_pixel_to_cell_y = 5'd16;
            else if (py < 10'd360) slot4_pixel_to_cell_y = 5'd17;
            else if (py < 10'd380) slot4_pixel_to_cell_y = 5'd18;
            else if (py < 10'd400) slot4_pixel_to_cell_y = 5'd19;
            else if (py < 10'd420) slot4_pixel_to_cell_y = 5'd20;
            else if (py < 10'd440) slot4_pixel_to_cell_y = 5'd21;
            else if (py < 10'd460) slot4_pixel_to_cell_y = 5'd22;
            else slot4_pixel_to_cell_y = 5'd23;
        end
    endfunction

    function [4:0] slot4_cell_local;
        input [9:0] p;
        input [4:0] cell_idx;
        reg [9:0] origin;
        begin
            origin = ({5'd0, cell_idx} << 4) + ({5'd0, cell_idx} << 2);
            slot4_cell_local = p - origin;
        end
    endfunction

    function [9:0] slot4_cell_origin;
        input [4:0] cell_idx;
        begin
            slot4_cell_origin = ({5'd0, cell_idx} << 4) + ({5'd0, cell_idx} << 2);
        end
    endfunction

    function [3:0] slot4_tile_at_pixel;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        reg [4:0] tx;
        reg [4:0] ty;
        begin
            if ((px >= SCREEN_W) || (py >= SCREEN_H)) begin
                slot4_tile_at_pixel = TILE_WALL;
            end else begin
                tx = slot4_pixel_to_cell_x(px);
                ty = slot4_pixel_to_cell_y(py);
                slot4_tile_at_pixel = slot4_tile_rom[slot4_tile_addr(lvl, tx, ty)];
            end
        end
    endfunction

    function slot4_solid_at;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        begin
            slot4_solid_at = slot4_is_solid_tile(slot4_tile_at_pixel(lvl, px, py), open_gate);
        end
    endfunction

    function slot4_player_solid;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        begin
            slot4_player_solid =
                slot4_solid_at(lvl, px, py, open_gate) ||
                slot4_solid_at(lvl, px + PLAYER_W - 1, py, open_gate) ||
                slot4_solid_at(lvl, px, py + PLAYER_H - 1, open_gate) ||
                slot4_solid_at(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1, open_gate);
        end
    endfunction

    function slot4_player_solid_x;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        input move_right;
        begin
            if (move_right) begin
                slot4_player_solid_x =
                    slot4_solid_at(lvl, px + PLAYER_W - 1, py + COLLIDE_INSET_Y, open_gate) ||
                    slot4_solid_at(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1 - COLLIDE_INSET_Y, open_gate);
            end else begin
                slot4_player_solid_x =
                    slot4_solid_at(lvl, px, py + COLLIDE_INSET_Y, open_gate) ||
                    slot4_solid_at(lvl, px, py + PLAYER_H - 1 - COLLIDE_INSET_Y, open_gate);
            end
        end
    endfunction

    function slot4_player_solid_y;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        input move_down;
        begin
            if (move_down) begin
                slot4_player_solid_y =
                    slot4_solid_at(lvl, px + COLLIDE_INSET_X, py + PLAYER_H - 1, open_gate) ||
                    slot4_solid_at(lvl, px + PLAYER_W - 1 - COLLIDE_INSET_X, py + PLAYER_H - 1, open_gate);
            end else begin
                slot4_player_solid_y =
                    slot4_solid_at(lvl, px + COLLIDE_INSET_X, py, open_gate) ||
                    slot4_solid_at(lvl, px + PLAYER_W - 1 - COLLIDE_INSET_X, py, open_gate);
            end
        end
    endfunction

    function slot4_player_grounded;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input open_gate;
        begin
            slot4_player_grounded =
                slot4_solid_at(lvl, px + COLLIDE_INSET_X, py + PLAYER_H, open_gate) ||
                slot4_solid_at(lvl, px + PLAYER_W - 1 - COLLIDE_INSET_X, py + PLAYER_H, open_gate);
        end
    endfunction

    task slot4_stage_solid_x_probe;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input move_right;
        reg [9:0] probe_x;
        reg [9:0] probe_y0;
        reg [9:0] probe_y1;
        begin
            probe_x = move_right ? (px + PLAYER_W - 1) : px;
            probe_y0 = py + COLLIDE_INSET_Y;
            probe_y1 = py + PLAYER_H - 1 - COLLIDE_INSET_Y;
            phys_probe_oob0_q <= (probe_x >= SCREEN_W) || (probe_y0 >= SCREEN_H);
            phys_probe_oob1_q <= (probe_x >= SCREEN_W) || (probe_y1 >= SCREEN_H);
            phys_probe_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(probe_x),
                                                  slot4_pixel_to_cell_y(probe_y0));
            phys_probe_addr1_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(probe_x),
                                                  slot4_pixel_to_cell_y(probe_y1));
        end
    endtask

    task slot4_stage_solid_y_probe;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input move_down;
        reg [9:0] probe_x0;
        reg [9:0] probe_x1;
        reg [9:0] probe_y;
        begin
            probe_x0 = px + COLLIDE_INSET_X;
            probe_x1 = px + PLAYER_W - 1 - COLLIDE_INSET_X;
            probe_y = move_down ? (py + PLAYER_H - 1) : py;
            phys_probe_oob0_q <= (probe_x0 >= SCREEN_W) || (probe_y >= SCREEN_H);
            phys_probe_oob1_q <= (probe_x1 >= SCREEN_W) || (probe_y >= SCREEN_H);
            phys_probe_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(probe_x0),
                                                  slot4_pixel_to_cell_y(probe_y));
            phys_probe_addr1_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(probe_x1),
                                                  slot4_pixel_to_cell_y(probe_y));
        end
    endtask

    task slot4_stage_status_probes;
        input [1:0] lvl;
        input [9:0] fx;
        input [9:0] fy;
        input [9:0] wx;
        input [9:0] wy;
        begin
            status_gate_open_q <= gate_open_now;
            status_fire_all_gems_q <= fire_all_gems;
            status_water_all_gems_q <= water_all_gems;
            fire_status_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(fx),
                                                   slot4_pixel_to_cell_y(fy));
            fire_status_addr1_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(fx + PLAYER_W - 1),
                                                   slot4_pixel_to_cell_y(fy));
            fire_status_addr2_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(fx),
                                                   slot4_pixel_to_cell_y(fy + PLAYER_H - 1));
            fire_status_addr3_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(fx + PLAYER_W - 1),
                                                   slot4_pixel_to_cell_y(fy + PLAYER_H - 1));
            water_status_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(wx),
                                                    slot4_pixel_to_cell_y(wy));
            water_status_addr1_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(wx + PLAYER_W - 1),
                                                    slot4_pixel_to_cell_y(wy));
            water_status_addr2_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(wx),
                                                    slot4_pixel_to_cell_y(wy + PLAYER_H - 1));
            water_status_addr3_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(wx + PLAYER_W - 1),
                                                    slot4_pixel_to_cell_y(wy + PLAYER_H - 1));
            fire_ground_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(fx + COLLIDE_INSET_X),
                                                   slot4_pixel_to_cell_y(fy + PLAYER_H));
            fire_ground_addr1_q <= slot4_tile_addr(lvl,
                                                   slot4_pixel_to_cell_x(fx + PLAYER_W - 1 - COLLIDE_INSET_X),
                                                   slot4_pixel_to_cell_y(fy + PLAYER_H));
            water_ground_addr0_q <= slot4_tile_addr(lvl, slot4_pixel_to_cell_x(wx + COLLIDE_INSET_X),
                                                    slot4_pixel_to_cell_y(wy + PLAYER_H));
            water_ground_addr1_q <= slot4_tile_addr(lvl,
                                                    slot4_pixel_to_cell_x(wx + PLAYER_W - 1 - COLLIDE_INSET_X),
                                                    slot4_pixel_to_cell_y(wy + PLAYER_H));
        end
    endtask

    function slot4_player_touch_tile;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        input [3:0] tile;
        begin
            slot4_player_touch_tile =
                (slot4_tile_at_pixel(lvl, px, py) == tile) ||
                (slot4_tile_at_pixel(lvl, px + PLAYER_W - 1, py) == tile) ||
                (slot4_tile_at_pixel(lvl, px, py + PLAYER_H - 1) == tile) ||
                (slot4_tile_at_pixel(lvl, px + PLAYER_W - 1, py + PLAYER_H - 1) == tile);
        end
    endfunction

    function slot4_fire_bad;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_fire_bad = slot4_player_touch_tile(lvl, px, py, TILE_WATER) ||
                             slot4_player_touch_tile(lvl, px, py, TILE_POISON);
        end
    endfunction

    function slot4_water_bad;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_water_bad = slot4_player_touch_tile(lvl, px, py, TILE_FIRE) ||
                              slot4_player_touch_tile(lvl, px, py, TILE_POISON);
        end
    endfunction

    function slot4_player_over_cell;
        input [9:0] px;
        input [9:0] py;
        input [4:0] tx;
        input [4:0] ty;
        reg [9:0] cell_left;
        reg [9:0] cell_top;
        begin
            cell_left = slot4_cell_origin(tx);
            cell_top = slot4_cell_origin(ty);
            slot4_player_over_cell =
                (px + PLAYER_W > cell_left) && (px < cell_left + CELL) &&
                (py + PLAYER_H > cell_top) && (py < cell_top + CELL);
        end
    endfunction

    function slot4_player_near_cell;
        input [9:0] px;
        input [9:0] py;
        input [4:0] tx;
        input [4:0] ty;
        begin
            slot4_player_near_cell =
                slot4_player_over_cell(px, py, tx, ty) ||
                ((tx > 5'd0) && slot4_player_over_cell(px, py, tx - 5'd1, ty)) ||
                ((tx < 5'd31) && slot4_player_over_cell(px, py, tx + 5'd1, ty)) ||
                ((ty > 5'd0) && slot4_player_over_cell(px, py, tx, ty - 5'd1)) ||
                ((ty < 5'd23) && slot4_player_over_cell(px, py, tx, ty + 5'd1));
        end
    endfunction

    function [3:0] slot4_fire_pick_mask;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_fire_pick_mask = 4'b0000;
            case (lvl)
                2'd0: begin
                    if (slot4_player_over_cell(px, py, 5'd9, 5'd3))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd11, 5'd12))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
                2'd1: begin
                    if (slot4_player_over_cell(px, py, 5'd6, 5'd17))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd12, 5'd9))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
                default: begin
                    if (slot4_player_over_cell(px, py, 5'd5, 5'd5))
                        slot4_fire_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd21, 5'd13))
                        slot4_fire_pick_mask[1] = 1'b1;
                end
            endcase
        end
    endfunction

    function [3:0] slot4_water_pick_mask;
        input [1:0] lvl;
        input [9:0] px;
        input [9:0] py;
        begin
            slot4_water_pick_mask = 4'b0000;
            case (lvl)
                2'd0: begin
                    if (slot4_player_over_cell(px, py, 5'd22, 5'd3))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd20, 5'd12))
                        slot4_water_pick_mask[1] = 1'b1;
                end
                2'd1: begin
                    if (slot4_player_over_cell(px, py, 5'd25, 5'd17))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd20, 5'd9))
                        slot4_water_pick_mask[1] = 1'b1;
                end
                default: begin
                    if (slot4_player_over_cell(px, py, 5'd26, 5'd5))
                        slot4_water_pick_mask[0] = 1'b1;
                    if (slot4_player_over_cell(px, py, 5'd10, 5'd13))
                        slot4_water_pick_mask[1] = 1'b1;
                end
            endcase
        end
    endfunction

    function [1:0] slot4_button_pick_mask;
        input [1:0] lvl;
        input [9:0] fx;
        input [9:0] fy;
        input [9:0] wx;
        input [9:0] wy;
        begin
            slot4_button_pick_mask = 2'b00;
            if (lvl == 2'd1) begin
                if (slot4_player_over_cell(fx, fy, 5'd15, 5'd17) ||
                    slot4_player_over_cell(wx, wy, 5'd15, 5'd17))
                    slot4_button_pick_mask[0] = 1'b1;
            end else if (lvl == 2'd2) begin
                if (slot4_player_over_cell(fx, fy, 5'd5, 5'd17) ||
                    slot4_player_over_cell(wx, wy, 5'd5, 5'd17))
                    slot4_button_pick_mask[0] = 1'b1;
                if (slot4_player_over_cell(fx, fy, 5'd26, 5'd17) ||
                    slot4_player_over_cell(wx, wy, 5'd26, 5'd17))
                    slot4_button_pick_mask[1] = 1'b1;
            end
        end
    endfunction

    function slot4_fire_gem_collected;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        input [3:0] mask;
        begin
            slot4_fire_gem_collected = 1'b0;
            case (lvl)
                2'd0: begin
                    if ((tx == 5'd9) && (ty == 5'd3))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd11) && (ty == 5'd12))
                        slot4_fire_gem_collected = mask[1];
                end
                2'd1: begin
                    if ((tx == 5'd6) && (ty == 5'd17))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd12) && (ty == 5'd9))
                        slot4_fire_gem_collected = mask[1];
                end
                default: begin
                    if ((tx == 5'd5) && (ty == 5'd5))
                        slot4_fire_gem_collected = mask[0];
                    else if ((tx == 5'd21) && (ty == 5'd13))
                        slot4_fire_gem_collected = mask[1];
                end
            endcase
        end
    endfunction

    function slot4_water_gem_collected;
        input [1:0] lvl;
        input [4:0] tx;
        input [4:0] ty;
        input [3:0] mask;
        begin
            slot4_water_gem_collected = 1'b0;
            case (lvl)
                2'd0: begin
                    if ((tx == 5'd22) && (ty == 5'd3))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd20) && (ty == 5'd12))
                        slot4_water_gem_collected = mask[1];
                end
                2'd1: begin
                    if ((tx == 5'd25) && (ty == 5'd17))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd20) && (ty == 5'd9))
                        slot4_water_gem_collected = mask[1];
                end
                default: begin
                    if ((tx == 5'd26) && (ty == 5'd5))
                        slot4_water_gem_collected = mask[0];
                    else if ((tx == 5'd10) && (ty == 5'd13))
                        slot4_water_gem_collected = mask[1];
                end
            endcase
        end
    endfunction

    function [6:0] slot4_seg_digit;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: slot4_seg_digit = 7'b0000001;
                4'd1: slot4_seg_digit = 7'b1001111;
                4'd2: slot4_seg_digit = 7'b0010010;
                4'd3: slot4_seg_digit = 7'b0000110;
                4'd4: slot4_seg_digit = 7'b1001100;
                4'd5: slot4_seg_digit = 7'b0100100;
                4'd6: slot4_seg_digit = 7'b0100000;
                4'd7: slot4_seg_digit = 7'b0001111;
                4'd8: slot4_seg_digit = 7'b0000000;
                4'd9: slot4_seg_digit = 7'b0000100;
                default: slot4_seg_digit = 7'b1111111;
            endcase
        end
    endfunction

    function [9:0] slot4_next_x_candidate;
        input [9:0] px;
        input left_cmd;
        input right_cmd;
        begin
            if (left_cmd && !right_cmd)
                slot4_next_x_candidate = (px > MOVE_STEP) ? px - MOVE_STEP : 10'd1;
            else if (right_cmd && !left_cmd)
                slot4_next_x_candidate = (px < SCREEN_W - PLAYER_W - MOVE_STEP) ?
                                         px + MOVE_STEP :
                                         SCREEN_W - PLAYER_W - 1;
            else
                slot4_next_x_candidate = px;
        end
    endfunction

    function signed [5:0] slot4_next_fire_vy;
        input signed [5:0] vy;
        input jump_cmd;
        input grounded;
        begin
            if (jump_cmd && grounded)
                slot4_next_fire_vy = JUMP_VEL;
            else if (vy < MAX_FALL)
                slot4_next_fire_vy = vy + GRAVITY;
            else
                slot4_next_fire_vy = vy;
        end
    endfunction

    function signed [5:0] slot4_next_water_vy;
        input signed [5:0] vy;
        input jump_cmd;
        input grounded;
        input down_cmd;
        reg signed [5:0] next_vy;
        begin
            if (jump_cmd && grounded) begin
                next_vy = JUMP_VEL;
            end else if (vy < MAX_FALL) begin
                next_vy = vy + GRAVITY;
                if (down_cmd && next_vy < MAX_FALL)
                    next_vy = next_vy + GRAVITY;
            end else begin
                next_vy = vy;
            end

            slot4_next_water_vy = next_vy;
        end
    endfunction

    function signed [11:0] slot4_next_y_calc;
        input [9:0] py;
        input signed [5:0] vy;
        begin
            slot4_next_y_calc = $signed({2'b00, py}) + {{6{vy[5]}}, vy};
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            frame_tick_q <= 1'b0;
            status_eval_q <= 1'b0;
            status_apply_q <= 1'b0;
            frame_step_q <= 1'b0;
            phys_state <= PHYS_IDLE;
            phys_x_candidate <= 10'd0;
            phys_y_candidate <= 12'sd0;
            phys_vy_candidate <= 6'sd0;
            phys_blocked_q <= 1'b0;
            phys_collision_skip_q <= 1'b0;
            phys_probe_addr0_q <= 12'd0;
            phys_probe_addr1_q <= 12'd0;
            phys_probe_oob0_q <= 1'b0;
            phys_probe_oob1_q <= 1'b0;
            status_gate_open_q <= 1'b1;
            status_fire_all_gems_q <= 1'b0;
            status_water_all_gems_q <= 1'b0;
            gate_open_eval_q <= 1'b1;
            fire_grounded_eval_q <= 1'b0;
            water_grounded_eval_q <= 1'b0;
            level_complete_eval_q <= 1'b0;
            level_failed_eval_q <= 1'b0;
            fire_status_addr0_q <= 12'd0;
            fire_status_addr1_q <= 12'd0;
            fire_status_addr2_q <= 12'd0;
            fire_status_addr3_q <= 12'd0;
            water_status_addr0_q <= 12'd0;
            water_status_addr1_q <= 12'd0;
            water_status_addr2_q <= 12'd0;
            water_status_addr3_q <= 12'd0;
            fire_ground_addr0_q <= 12'd0;
            fire_ground_addr1_q <= 12'd0;
            water_ground_addr0_q <= 12'd0;
            water_ground_addr1_q <= 12'd0;
            btn_u_sync0 <= 1'b0;
            btn_u_sync1 <= 1'b0;
            btn_d_sync0 <= 1'b0;
            btn_d_sync1 <= 1'b0;
            btn_l_sync0 <= 1'b0;
            btn_l_sync1 <= 1'b0;
            btn_r_sync0 <= 1'b0;
            btn_r_sync1 <= 1'b0;
            btn_c_sync0 <= 1'b0;
            btn_c_sync1 <= 1'b0;
            sw0_sync0 <= 1'b0;
            sw0_sync1 <= 1'b0;
            sw1_sync0 <= 1'b0;
            sw1_sync1 <= 1'b0;
            sw2_sync0 <= 1'b0;
            sw2_sync1 <= 1'b0;
            btn_u_q <= 1'b0;
            btn_d_q <= 1'b0;
            btn_l_q <= 1'b0;
            btn_r_q <= 1'b0;
            btn_c_q <= 1'b0;
            fire_left_key_q <= 1'b0;
            fire_right_key_q <= 1'b0;
            fire_jump_key_q <= 1'b0;
            water_left_key_q <= 1'b0;
            water_right_key_q <= 1'b0;
            water_jump_key_q <= 1'b0;
            water_down_key_q <= 1'b0;
            sw0_q <= 1'b0;
            sw1_q <= 1'b0;
            sw2_q <= 1'b0;
            gate_open_q <= 1'b1;
            fire_grounded_q <= 1'b0;
            water_grounded_q <= 1'b0;
            fire_pick_mask_q <= 2'b00;
            water_pick_mask_q <= 2'b00;
            button_pick_mask_q <= 2'b00;
            level_complete_q <= 1'b0;
            level_failed_q <= 1'b0;
            level <= 2'd0;
            won <= 1'b0;
            fire_x <= slot4_fire_start_x(2'd0);
            fire_y <= slot4_fire_start_y(2'd0);
            water_x <= slot4_water_start_x(2'd0);
            water_y <= slot4_water_start_y(2'd0);
            fire_vy <= 6'sd0;
            water_vy <= 6'sd0;
            fire_gems <= 4'b0000;
            water_gems <= 4'b0000;
            button_mask <= 2'b00;
            frame_counter <= 24'd0;
            selected_video_q <= 1'b0;
            display_active_video_q <= 1'b0;
            level_video_q <= 2'd0;
            won_video_q <= 1'b0;
            fire_x_video_q <= slot4_fire_start_x(2'd0);
            fire_y_video_q <= slot4_fire_start_y(2'd0);
            water_x_video_q <= slot4_water_start_x(2'd0);
            water_y_video_q <= slot4_water_start_y(2'd0);
            fire_gems_video_q <= 4'b0000;
            water_gems_video_q <= 4'b0000;
            gate_open_video_q <= 1'b1;
            frame_counter_video_q <= 24'd0;
        end else begin
            frame_tick_q <= frame_tick && (phys_state == PHYS_IDLE);
            status_eval_q <= selected && frame_tick_q;
            status_apply_q <= status_eval_q;
            frame_step_q <= status_apply_q;
            btn_u_sync0 <= btn_u;
            btn_u_sync1 <= btn_u_sync0;
            btn_d_sync0 <= btn_d;
            btn_d_sync1 <= btn_d_sync0;
            btn_l_sync0 <= btn_l;
            btn_l_sync1 <= btn_l_sync0;
            btn_r_sync0 <= btn_r;
            btn_r_sync1 <= btn_r_sync0;
            btn_c_sync0 <= btn_c;
            btn_c_sync1 <= btn_c_sync0;
            sw0_sync0 <= sw[0];
            sw0_sync1 <= sw0_sync0;
            sw1_sync0 <= sw[1];
            sw1_sync1 <= sw1_sync0;
            sw2_sync0 <= sw[2];
            sw2_sync1 <= sw2_sync0;

            if (pixel_tick) begin
                selected_video_q <= selected;
                display_active_video_q <= display_active;
                level_video_q <= level;
                won_video_q <= won;
                fire_x_video_q <= fire_x;
                fire_y_video_q <= fire_y;
                water_x_video_q <= water_x;
                water_y_video_q <= water_y;
                fire_gems_video_q <= fire_gems;
                water_gems_video_q <= water_gems;
                gate_open_video_q <= gate_open;
                frame_counter_video_q <= frame_counter;
            end

            if (frame_tick) begin
                btn_u_q <= btn_u_sync1;
                btn_d_q <= btn_d_sync1;
                btn_l_q <= btn_l_sync1;
                btn_r_q <= btn_r_sync1;
                btn_c_q <= btn_c_sync1;
                fire_left_key_q <= fire_left_key;
                fire_right_key_q <= fire_right_key;
                fire_jump_key_q <= fire_jump_key;
                water_left_key_q <= water_left_key;
                water_right_key_q <= water_right_key;
                water_jump_key_q <= water_jump_key;
                water_down_key_q <= water_down_key;
                sw0_q <= sw0_sync1;
                sw1_q <= sw1_sync1;
                sw2_q <= sw2_sync1;
            end

            if (frame_tick_q) begin
                slot4_stage_status_probes(level, fire_x, fire_y, water_x, water_y);
            end

            if (status_eval_q) begin
                gate_open_eval_q <= status_gate_open_q;
                fire_grounded_eval_q <= fire_grounded_eval_now;
                water_grounded_eval_q <= water_grounded_eval_now;
                level_complete_eval_q <= level_complete_eval_now;
                level_failed_eval_q <= level_failed_eval_now;
            end

            if (status_apply_q) begin
                gate_open_q <= gate_open_eval_q;
                fire_grounded_q <= fire_grounded_now;
                water_grounded_q <= water_grounded_now;
                fire_pick_mask_q <= fire_pick_mask_now;
                water_pick_mask_q <= water_pick_mask_now;
                button_pick_mask_q <= button_pick_mask_now;
                level_complete_q <= level_complete_now;
                level_failed_q <= level_failed_now;
            end

            case (phys_state)
                PHYS_IDLE: begin
                    if (selected && frame_step_q) begin
                        frame_counter <= frame_counter + 24'd1;

                        if (btn_c_q) begin
                            fire_x <= slot4_fire_start_x(level);
                            fire_y <= slot4_fire_start_y(level);
                            water_x <= slot4_water_start_x(level);
                            water_y <= slot4_water_start_y(level);
                            fire_vy <= 6'sd0;
                            water_vy <= 6'sd0;
                            fire_gems <= 4'b0000;
                            water_gems <= 4'b0000;
                            button_mask <= 2'b00;
                            won <= 1'b0;
                        end else if (!won) begin
                            fire_gems <= fire_gems | fire_pick_mask_q;
                            water_gems <= water_gems | water_pick_mask_q;
                            button_mask <= button_mask | button_pick_mask_q;

                            if (level_failed_q) begin
                                fire_x <= slot4_fire_start_x(level);
                                fire_y <= slot4_fire_start_y(level);
                                water_x <= slot4_water_start_x(level);
                                water_y <= slot4_water_start_y(level);
                                fire_vy <= 6'sd0;
                                water_vy <= 6'sd0;
                                fire_gems <= 4'b0000;
                                water_gems <= 4'b0000;
                                button_mask <= 2'b00;
                            end else if (level_complete_q) begin
                                if (level == 2'd2) begin
                                    won <= 1'b1;
                                end else begin
                                    next_level = level + 2'd1;
                                    level <= next_level;
                                    fire_x <= slot4_fire_start_x(next_level);
                                    fire_y <= slot4_fire_start_y(next_level);
                                    water_x <= slot4_water_start_x(next_level);
                                    water_y <= slot4_water_start_y(next_level);
                                    fire_vy <= 6'sd0;
                                    water_vy <= 6'sd0;
                                    fire_gems <= 4'b0000;
                                    water_gems <= 4'b0000;
                                    button_mask <= 2'b00;
                                end
                            end else begin
                                phys_x_candidate <= slot4_next_x_candidate(fire_x, fire_left_cmd, fire_right_cmd);
                                phys_state <= PHYS_FIRE_X_TEST;
                            end
                        end
                    end
                end

                PHYS_FIRE_X_TEST: begin
                    phys_collision_skip_q <= (phys_x_candidate == fire_x);
                    slot4_stage_solid_x_probe(level, phys_x_candidate, fire_y, phys_x_candidate > fire_x);
                    phys_state <= PHYS_FIRE_X_EVAL;
                end

                PHYS_FIRE_X_EVAL: begin
                    phys_blocked_q <= phys_collision_skip_q ? 1'b0 : phys_probe_solid;
                    phys_state <= PHYS_FIRE_X_APPLY;
                end

                PHYS_FIRE_X_APPLY: begin
                    if (!phys_blocked_q)
                        fire_x <= phys_x_candidate;
                    phys_x_candidate <= slot4_next_x_candidate(water_x, water_left_cmd, water_right_cmd);
                    phys_state <= PHYS_WATER_X_TEST;
                end

                PHYS_WATER_X_TEST: begin
                    phys_collision_skip_q <= (phys_x_candidate == water_x);
                    slot4_stage_solid_x_probe(level, phys_x_candidate, water_y, phys_x_candidate > water_x);
                    phys_state <= PHYS_WATER_X_EVAL;
                end

                PHYS_WATER_X_EVAL: begin
                    phys_blocked_q <= phys_collision_skip_q ? 1'b0 : phys_probe_solid;
                    phys_state <= PHYS_WATER_X_APPLY;
                end

                PHYS_WATER_X_APPLY: begin
                    if (!phys_blocked_q)
                        water_x <= phys_x_candidate;
                    phys_vy_candidate <= slot4_next_fire_vy(fire_vy, fire_jump_cmd, fire_grounded_q);
                    phys_y_candidate <= slot4_next_y_calc(fire_y,
                                                          slot4_next_fire_vy(fire_vy, fire_jump_cmd, fire_grounded_q));
                    phys_state <= PHYS_FIRE_Y_TEST;
                end

                PHYS_FIRE_Y_TEST: begin
                    phys_collision_skip_q <= (phys_y_candidate < 12'sd1) ||
                                             (phys_y_candidate > SCREEN_H - PLAYER_H - 1);
                    slot4_stage_solid_y_probe(level, fire_x, phys_y_candidate[9:0],
                                              phys_vy_candidate > 6'sd0);
                    phys_state <= PHYS_FIRE_Y_EVAL;
                end

                PHYS_FIRE_Y_EVAL: begin
                    phys_blocked_q <= phys_collision_skip_q ? 1'b0 : phys_probe_solid;
                    phys_state <= PHYS_FIRE_Y_APPLY;
                end

                PHYS_FIRE_Y_APPLY: begin
                    if (phys_y_candidate < 12'sd1) begin
                        fire_y <= 10'd1;
                        fire_vy <= 6'sd0;
                    end else if (phys_y_candidate > SCREEN_H - PLAYER_H - 1) begin
                        fire_y <= SCREEN_H - PLAYER_H - 1;
                        fire_vy <= 6'sd0;
                    end else if (!phys_blocked_q) begin
                        fire_y <= phys_y_candidate[9:0];
                        fire_vy <= phys_vy_candidate;
                    end else begin
                        fire_vy <= 6'sd0;
                    end

                    phys_vy_candidate <= slot4_next_water_vy(water_vy, water_jump_cmd, water_grounded_q,
                                                             water_down_cmd);
                    phys_y_candidate <= slot4_next_y_calc(water_y,
                                                          slot4_next_water_vy(water_vy, water_jump_cmd,
                                                                              water_grounded_q, water_down_cmd));
                    phys_state <= PHYS_WATER_Y_TEST;
                end

                PHYS_WATER_Y_TEST: begin
                    phys_collision_skip_q <= (phys_y_candidate < 12'sd1) ||
                                             (phys_y_candidate > SCREEN_H - PLAYER_H - 1);
                    slot4_stage_solid_y_probe(level, water_x, phys_y_candidate[9:0],
                                              phys_vy_candidate > 6'sd0);
                    phys_state <= PHYS_WATER_Y_EVAL;
                end

                PHYS_WATER_Y_EVAL: begin
                    phys_blocked_q <= phys_collision_skip_q ? 1'b0 : phys_probe_solid;
                    phys_state <= PHYS_WATER_Y_APPLY;
                end

                PHYS_WATER_Y_APPLY: begin
                    if (phys_y_candidate < 12'sd1) begin
                        water_y <= 10'd1;
                        water_vy <= 6'sd0;
                    end else if (phys_y_candidate > SCREEN_H - PLAYER_H - 1) begin
                        water_y <= SCREEN_H - PLAYER_H - 1;
                        water_vy <= 6'sd0;
                    end else if (!phys_blocked_q) begin
                        water_y <= phys_y_candidate[9:0];
                        water_vy <= phys_vy_candidate;
                    end else begin
                        water_vy <= 6'sd0;
                    end
                    phys_state <= PHYS_IDLE;
                end

                default: begin
                    phys_state <= PHYS_IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        cell_x = slot4_pixel_to_cell_x(pixel_x);
        cell_y = slot4_pixel_to_cell_y(pixel_y);
        local_x = slot4_cell_local(pixel_x, cell_x);
        local_y = slot4_cell_local(pixel_y, cell_y);
        draw_tile = slot4_tile_rom[slot4_tile_addr(level_video_q, cell_x, cell_y)];

        if ((draw_tile == TILE_FIRE_GEM) && slot4_fire_gem_collected(level_video_q, cell_x, cell_y, fire_gems_video_q))
            draw_tile = TILE_EMPTY;
        else if ((draw_tile == TILE_WATER_GEM) && slot4_water_gem_collected(level_video_q, cell_x, cell_y, water_gems_video_q))
            draw_tile = TILE_EMPTY;
        else if ((draw_tile == TILE_GATE) && gate_open_video_q)
            draw_tile = TILE_EMPTY;

        if (!display_active_video_q || !selected_video_q) begin
            render_r = 4'h0;
            render_g = 4'h0;
            render_b = 4'h0;
        end else if (won_video_q) begin
            render_r = pixel_x[5] ^ pixel_y[4] ? 4'hF : 4'h2;
            render_g = pixel_x[6] ^ frame_counter_video_q[4] ? 4'hD : 4'h4;
            render_b = pixel_y[5] ^ frame_counter_video_q[3] ? 4'h7 : 4'hF;
        end else if (fire_eye || water_eye) begin
            render_r = 4'h1;
            render_g = 4'h1;
            render_b = 4'h1;
        end else if (fire_pixel) begin
            if (pixel_y < fire_y_video_q + 10'd4) begin
                render_r = 4'hF;
                render_g = 4'hC;
                render_b = 4'h2;
            end else begin
                render_r = 4'hE;
                render_g = 4'h3 + frame_counter_video_q[3];
                render_b = 4'h1;
            end
        end else if (water_pixel) begin
            if (pixel_y < water_y_video_q + 10'd4) begin
                render_r = 4'h9;
                render_g = 4'hF;
                render_b = 4'hF;
            end else begin
                render_r = 4'h1;
                render_g = 4'h8;
                render_b = 4'hF;
            end
        end else begin
            render_r = 4'h0;
            render_g = 4'h1 + {2'b00, pixel_y[6:5]};
            render_b = 4'h3 + {2'b00, pixel_x[6:5]};

            case (draw_tile)
                TILE_WALL: begin
                    if ((local_x == 5'd0) || (local_y == 5'd0) ||
                        (local_x == 5'd19) || (local_y == 5'd19)) begin
                        render_r = 4'h9;
                        render_g = 4'h9;
                        render_b = 4'h9;
                    end else if (local_y < 5'd4) begin
                        render_r = 4'h6;
                        render_g = 4'h6;
                        render_b = 4'h7;
                    end else begin
                        render_r = 4'h3;
                        render_g = 4'h3;
                        render_b = 4'h4;
                    end
                end
                TILE_FIRE: begin
                    render_r = 4'hF;
                    render_g = (local_y[2] ^ frame_counter_video_q[3]) ? 4'h6 : 4'h2;
                    render_b = 4'h0;
                end
                TILE_WATER: begin
                    render_r = 4'h0;
                    render_g = (local_x[2] ^ frame_counter_video_q[3]) ? 4'h9 : 4'hC;
                    render_b = 4'hF;
                end
                TILE_POISON: begin
                    render_r = 4'h3;
                    render_g = (local_x[2] ^ local_y[2] ^ frame_counter_video_q[3]) ? 4'hF : 4'h9;
                    render_b = 4'h2;
                end
                TILE_FIRE_GEM: begin
                    if ((local_x >= 5'd5) && (local_x <= 5'd14) &&
                        (local_y >= 5'd4) && (local_y <= 5'd15)) begin
                        render_r = 4'hF;
                        render_g = 4'h6 + frame_counter_video_q[3];
                        render_b = 4'h2;
                    end
                end
                TILE_WATER_GEM: begin
                    if ((local_x >= 5'd5) && (local_x <= 5'd14) &&
                        (local_y >= 5'd4) && (local_y <= 5'd15)) begin
                        render_r = 4'h4;
                        render_g = 4'hC;
                        render_b = 4'hF;
                    end
                end
                TILE_FIRE_DOOR: begin
                    if ((local_x < 5'd3) || (local_x > 5'd16) || (local_y < 5'd3)) begin
                        render_r = 4'hF;
                        render_g = 4'h4;
                        render_b = 4'h1;
                    end else begin
                        render_r = 4'h5;
                        render_g = 4'h1;
                        render_b = 4'h0;
                    end
                end
                TILE_WATER_DOOR: begin
                    if ((local_x < 5'd3) || (local_x > 5'd16) || (local_y < 5'd3)) begin
                        render_r = 4'h2;
                        render_g = 4'hC;
                        render_b = 4'hF;
                    end else begin
                        render_r = 4'h0;
                        render_g = 4'h2;
                        render_b = 4'h6;
                    end
                end
                TILE_BUTTON: begin
                    if ((local_y >= 5'd12) && (local_y <= 5'd16) &&
                        (local_x >= 5'd4) && (local_x <= 5'd15)) begin
                        render_r = gate_open_video_q ? 4'h5 : 4'hF;
                        render_g = gate_open_video_q ? 4'hF : 4'hD;
                        render_b = 4'h2;
                    end
                end
                TILE_GATE: begin
                    if ((local_x < 5'd5) || (local_x > 5'd14)) begin
                        render_r = 4'hB;
                        render_g = 4'hC;
                        render_b = 4'hD;
                    end else begin
                        render_r = 4'h4;
                        render_g = 4'h5;
                        render_b = 4'h7;
                    end
                end
                default: begin
                    if ((local_x == 5'd0) || (local_y == 5'd0)) begin
                        render_r = 4'h0;
                        render_g = 4'h0;
                        render_b = 4'h2;
                    end
                end
            endcase
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

    always @(*) begin
        if (!selected) begin
            seg_n = 7'b1111111;
        end else if (won) begin
            seg_n = slot4_seg_digit(4'd8);
        end else begin
            seg_n = slot4_seg_digit({2'b00, level} + 4'd1);
        end
    end

    assign led = selected ? {
        won,
        gate_open,
        button_mask,
        water_gems[1:0],
        fire_gems[1:0],
        4'b0000,
        level,
        fire_grounded,
        water_grounded
    } : 16'h0000;

    assign an = selected ? 8'b1111_1110 : 8'b1111_1111;
    assign {ca, cb, cc, cd, ce, cf, cg} = seg_n;
    assign dp = 1'b1;
    assign buzzer = 1'b1;

endmodule

module slot4_keyboard_mapper (
    input  wire       clk,
    input  wire       reset,
    input  wire       byte_ready,
    input  wire [7:0] byte_data,
    output reg        fire_left,
    output reg        fire_right,
    output reg        fire_jump,
    output reg        water_left,
    output reg        water_right,
    output reg        water_jump,
    output reg        water_down
);

    localparam [7:0] SCAN_F0    = 8'hF0;
    localparam [7:0] SCAN_E0    = 8'hE0;
    localparam [7:0] SCAN_W     = 8'h1D;
    localparam [7:0] SCAN_A     = 8'h1C;
    localparam [7:0] SCAN_S     = 8'h1B;
    localparam [7:0] SCAN_D     = 8'h23;
    localparam [7:0] SCAN_UP    = 8'h75;
    localparam [7:0] SCAN_DOWN  = 8'h72;
    localparam [7:0] SCAN_LEFT  = 8'h6B;
    localparam [7:0] SCAN_RIGHT = 8'h74;

    reg break_pending;
    reg extend_pending;

    always @(posedge clk) begin
        if (reset) begin
            fire_left <= 1'b0;
            fire_right <= 1'b0;
            fire_jump <= 1'b0;
            water_left <= 1'b0;
            water_right <= 1'b0;
            water_jump <= 1'b0;
            water_down <= 1'b0;
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
        end else if (byte_ready) begin
            if (byte_data == SCAN_F0) begin
                break_pending <= 1'b1;
            end else if (byte_data == SCAN_E0) begin
                extend_pending <= 1'b1;
            end else begin
                case (byte_data)
                    SCAN_A: fire_left  <= ~break_pending;
                    SCAN_D: fire_right <= ~break_pending;
                    SCAN_W: fire_jump  <= ~break_pending;
                    SCAN_S: water_down <= ~break_pending;
                    SCAN_LEFT:  water_left  <= ~break_pending;
                    SCAN_RIGHT: water_right <= ~break_pending;
                    SCAN_UP:    water_jump  <= ~break_pending;
                    SCAN_DOWN: water_down <= ~break_pending;
                    default: begin end
                endcase

                break_pending <= 1'b0;
                extend_pending <= 1'b0;
            end
        end
    end

endmodule
