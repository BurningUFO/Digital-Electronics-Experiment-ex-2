// Tank War game logic and renderer for slot 1.
//
// This module consumes the console-provided VGA coordinate stream and PS/2 byte
// events.  It owns Tank War screens, two-player input state, movement/collision,
// bullets, hit/life handling, map selection, sprite composition, seven-segment
// output, LEDs, and buzzer patterns.
module tank_top (
    input  wire       CLK100MHZ,
    input  wire       reset,
    input  wire       selected,
    input  wire       pixel_tick,
    input  wire       display_active,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       ps2_byte_ready,
    input  wire [7:0] ps2_byte_data,
    output wire       BUZZER,
    output wire [15:0] LED,
    output wire [7:0] AN,
    output wire       CA,
    output wire       CB,
    output wire       CC,
    output wire       CD,
    output wire       CE,
    output wire       CF,
    output wire       CG,
    output wire       DP,
    output reg  [3:0] VGA_R,
    output reg  [3:0] VGA_G,
    output reg  [3:0] VGA_B
);

    reg [3:0] rgb_r;
    reg [3:0] rgb_g;
    reg [3:0] rgb_b;

    wire [5:0] tile_x;
    wire [4:0] tile_y;
    wire [1:0] tile_type;
    wire [3:0] tile_r;
    wire [3:0] tile_g;
    wire [3:0] tile_b;
    wire [3:0] local_x;
    wire [3:0] local_y;
    wire       p1_pixel_on;
    wire       p2_pixel_on;
    wire       p1_up;
    wire       p1_left;
    wire       p1_down;
    wire       p1_right;
    wire       p1_fire;
    wire       p2_up;
    wire       p2_left;
    wire       p2_down;
    wire       p2_right;
    wire       p2_fire;
    wire       move_tick;
    wire       bullet_tick;
    wire [1:0] p1_move_dir;
    wire [1:0] p2_move_dir;
    wire       p1_move_req;
    wire       p2_move_req;
    wire       p1_fire_pulse;
    wire       p2_fire_pulse;
    wire [10:0] p1_next_x;
    wire [9:0]  p1_next_y;
    wire [10:0] p2_next_x;
    wire [9:0]  p2_next_y;
    wire       p1_move_ok;
    wire       p2_move_ok;
    wire       p1_in_box;
    wire       p2_in_box;
    wire [3:0] p1_local_x;
    wire [3:0] p1_local_y;
    wire [3:0] p2_local_x;
    wire [3:0] p2_local_y;
    wire [10:0] p1_bullet_next_x;
    wire [9:0]  p1_bullet_next_y;
    wire        p1_bullet_move_ok;
    wire        p1_bullet_in_box;
    wire [3:0]  p1_bullet_local_x;
    wire [3:0]  p1_bullet_local_y;
    wire        p1_bullet_pixel_on;
    wire [10:0] p1_bullet_spawn_x;
    wire [9:0]  p1_bullet_spawn_y;
    wire        p1_bullet_spawn_ok;
    wire [10:0] p2_bullet_next_x;
    wire [9:0]  p2_bullet_next_y;
    wire        p2_bullet_move_ok;
    wire        p2_bullet_in_box;
    wire [3:0]  p2_bullet_local_x;
    wire [3:0]  p2_bullet_local_y;
    wire        p2_bullet_pixel_on;
    wire [10:0] p2_bullet_spawn_x;
    wire [9:0]  p2_bullet_spawn_y;
    wire        p2_bullet_spawn_ok;
    wire [10:0] p1_effective_x;
    wire [9:0]  p1_effective_y;
    wire [10:0] p2_effective_x;
    wire [9:0]  p2_effective_y;
    wire        bullets_overlap_now;
    wire        bullets_overlap_next;
    wire        p1_hit_by_p2_now;
    wire        p1_hit_by_p2_next;
    wire        p2_hit_by_p1_now;
    wire        p2_hit_by_p1_next;
    wire [10:0] explosion_now_x;
    wire [9:0]  explosion_now_y;
    wire [10:0] explosion_next_x;
    wire [9:0]  explosion_next_y;
    wire        explosion_in_box;
    wire [3:0]  explosion_local_x;
    wire [3:0]  explosion_local_y;
    wire        explosion_pixel_on;
    wire        p1_hit_event;
    wire        p2_hit_event;
    wire [3:0]  seg_digit;
    wire [6:0]  seg_pattern_n;
    wire        nav_up;
    wire        nav_down;
    wire        nav_left;
    wire        nav_right;
    wire        nav_fire_pulse;
    wire        play_enable;
    wire [10:0] spawn_p1_x;
    wire [9:0]  spawn_p1_y;
    wire [1:0]  spawn_p1_dir;
    wire [10:0] spawn_p2_x;
    wire [9:0]  spawn_p2_y;
    wire [1:0]  spawn_p2_dir;
    wire        ui_overlay_on;
    wire [3:0]  ui_r;
    wire [3:0]  ui_g;
    wire [3:0]  ui_b;
    wire        ui_blink_on;
    wire        buzzer_n;

    reg [10:0] p1_x;
    reg [9:0]  p1_y;
    reg [1:0]  p1_dir;
    reg [10:0] p2_x;
    reg [9:0]  p2_y;
    reg [1:0]  p2_dir;
    reg [10:0] p1_bullet_x;
    reg [9:0]  p1_bullet_y;
    reg [1:0]  p1_bullet_dir;
    reg        p1_bullet_active;
    reg        p1_fire_prev;
    reg [10:0] p2_bullet_x;
    reg [9:0]  p2_bullet_y;
    reg [1:0]  p2_bullet_dir;
    reg        p2_bullet_active;
    reg        p2_fire_prev;
    reg [10:0] explosion_x;
    reg [9:0]  explosion_y;
    reg [1:0]  explosion_phase;
    reg        explosion_active;
    reg        explosion_subtick;
    reg [1:0]  p1_lives;
    reg [1:0]  p2_lives;
    reg        title_screen;
    reg        menu_screen;
    reg        map_select_screen;
    reg        game_over;
    reg [1:0]  game_result;
    reg        menu_index;
    reg [2:0]  selected_map_id;
    reg [2:0]  map_select_idx;
    reg        seg_scan_sel;
    reg [16:0] seg_refresh_counter;
    reg [25:0] ui_blink_counter;
    reg        fire_beep_req;
    reg        hit_beep_req;
    reg        game_over_beep_req;
    reg [10:0] p1_bullet_spawn_x_q;
    reg [9:0]  p1_bullet_spawn_y_q;
    reg        p1_bullet_spawn_ok_q;
    reg [10:0] p2_bullet_spawn_x_q;
    reg [9:0]  p2_bullet_spawn_y_q;
    reg        p2_bullet_spawn_ok_q;
    reg [10:0] p1_bullet_next_x_q;
    reg [9:0]  p1_bullet_next_y_q;
    reg        p1_bullet_move_ok_q;
    reg [10:0] p2_bullet_next_x_q;
    reg [9:0]  p2_bullet_next_y_q;
    reg        p2_bullet_move_ok_q;
    reg        bullets_overlap_now_q;
    reg        bullets_overlap_next_q;
    reg        p1_hit_event_q;
    reg        p2_hit_event_q;
    reg [10:0] p1_hit_explosion_x_q;
    reg [9:0]  p1_hit_explosion_y_q;
    reg [10:0] p2_hit_explosion_x_q;
    reg [9:0]  p2_hit_explosion_y_q;
    reg [10:0] explosion_now_x_q;
    reg [9:0]  explosion_now_y_q;
    reg [10:0] explosion_next_x_q;
    reg [9:0]  explosion_next_y_q;
    reg        p1_move_pending;
    reg        p2_move_pending;
    reg [1:0]  p1_move_dir_q;
    reg [1:0]  p2_move_dir_q;
    reg [10:0] p1_move_check_x;
    reg [9:0]  p1_move_check_y;
    reg [10:0] p1_move_blocker_x;
    reg [9:0]  p1_move_blocker_y;
    reg [10:0] p2_move_check_x;
    reg [9:0]  p2_move_check_y;
    reg [10:0] p2_move_blocker_x;
    reg [9:0]  p2_move_blocker_y;

    // Gameplay constants: spawn locations, directions, map IDs, and result IDs.
    localparam [5:0] P1_TILE_X = 6'd2;
    localparam [4:0] P1_TILE_Y = 5'd26;
    localparam [1:0] DIR_UP    = 2'd0;
    localparam [1:0] DIR_RIGHT = 2'd1;
    localparam [1:0] DIR_DOWN  = 2'd2;
    localparam [1:0] DIR_LEFT  = 2'd3;
    localparam [10:0] P1_START_X = 11'd32;
    localparam [9:0]  P1_START_Y = 10'd416;
    localparam [10:0] BULLET_SIZE_X = 11'd6;
    localparam [9:0]  BULLET_SIZE_Y = 10'd6;

    localparam [5:0] P2_TILE_X = 6'd37;
    localparam [4:0] P2_TILE_Y = 5'd3;
    localparam [10:0] P2_START_X = 11'd592;
    localparam [9:0]  P2_START_Y = 10'd48;
    localparam [1:0]  P2_DIR = DIR_LEFT;
    localparam [10:0] EXPLOSION_SIZE_X = 11'd16;
    localparam [9:0]  EXPLOSION_SIZE_Y = 10'd16;
    localparam [16:0] SEG_REFRESH_DIV = 17'd100_000;
    localparam [2:0] MAP_CLASSIC  = 3'd0;
    localparam [2:0] MAP_LANES    = 3'd1;
    localparam [2:0] MAP_FORTRESS = 3'd2;
    localparam [2:0] MAP_MAZE     = 3'd3;
    localparam [2:0] MAP_OPEN     = 3'd4;
    localparam [2:0] MAP_QUAD     = 3'd5;
    localparam [1:0] RESULT_NONE = 2'd0;
    localparam [1:0] RESULT_P1   = 2'd1;
    localparam [1:0] RESULT_P2   = 2'd2;
    localparam [1:0] RESULT_DRAW = 2'd3;

    assign tile_x = pixel_x[9:4];
    assign tile_y = pixel_y[8:4];
    assign local_x = pixel_x[3:0];
    assign local_y = pixel_y[3:0];
    assign p1_move_req = p1_up | p1_right | p1_down | p1_left;
    assign p2_move_req = p2_up | p2_right | p2_down | p2_left;

    assign p1_move_dir = p1_up    ? DIR_UP    :
                         p1_right ? DIR_RIGHT :
                         p1_down  ? DIR_DOWN  :
                                    DIR_LEFT;

    assign p2_move_dir = p2_up    ? DIR_UP    :
                         p2_right ? DIR_RIGHT :
                         p2_down  ? DIR_DOWN  :
                                    DIR_LEFT;

    assign p1_fire_pulse = p1_fire & ~p1_fire_prev;
    assign p2_fire_pulse = p2_fire & ~p2_fire_prev;
    assign nav_up = p1_up | p2_up;
    assign nav_down = p1_down | p2_down;
    assign nav_left = p1_left | p2_left;
    assign nav_right = p1_right | p2_right;
    assign nav_fire_pulse = p1_fire_pulse | p2_fire_pulse;
    assign play_enable = ~title_screen & ~menu_screen & ~map_select_screen & ~game_over;
`ifdef SIM_FAST_VGA
    assign ui_blink_on = ui_blink_counter[23];
`else
    assign ui_blink_on = ui_blink_counter[25];
`endif

    assign spawn_p1_x = (selected_map_id == MAP_FORTRESS) ? 11'd64  :
                        (selected_map_id == MAP_MAZE)     ? 11'd48  :
                        (selected_map_id == MAP_QUAD)     ? 11'd64  :
                                                             11'd48;

    assign spawn_p1_y = (selected_map_id == MAP_FORTRESS) ? 10'd400 :
                        (selected_map_id == MAP_MAZE)     ? 10'd48  :
                        (selected_map_id == MAP_QUAD)     ? 10'd416 :
                                                             10'd240;

    assign spawn_p1_dir = (selected_map_id == MAP_FORTRESS) ? DIR_UP :
                          (selected_map_id == MAP_QUAD)     ? DIR_UP :
                                                              DIR_RIGHT;

    assign spawn_p2_x = (selected_map_id == MAP_FORTRESS) ? 11'd560 :
                        (selected_map_id == MAP_MAZE)     ? 11'd576 :
                        (selected_map_id == MAP_QUAD)     ? 11'd560 :
                                                             11'd576;

    assign spawn_p2_y = (selected_map_id == MAP_FORTRESS) ? 10'd64  :
                        (selected_map_id == MAP_MAZE)     ? 10'd416 :
                        (selected_map_id == MAP_QUAD)     ? 10'd48  :
                                                             10'd240;

    assign spawn_p2_dir = (selected_map_id == MAP_FORTRESS) ? DIR_DOWN :
                          (selected_map_id == MAP_QUAD)     ? DIR_DOWN :
                                                              DIR_LEFT;

    assign p1_next_x = (p1_move_dir == DIR_LEFT)  ? (p1_x - 11'd2) :
                       (p1_move_dir == DIR_RIGHT) ? (p1_x + 11'd2) :
                                                 p1_x;

    assign p1_next_y = (p1_move_dir == DIR_UP)    ? (p1_y - 10'd2) :
                       (p1_move_dir == DIR_DOWN)  ? (p1_y + 10'd2) :
                                                 p1_y;

    assign p2_next_x = (p2_move_dir == DIR_LEFT)  ? (p2_x - 11'd2) :
                       (p2_move_dir == DIR_RIGHT) ? (p2_x + 11'd2) :
                                                    p2_x;

    assign p2_next_y = (p2_move_dir == DIR_UP)    ? (p2_y - 10'd2) :
                       (p2_move_dir == DIR_DOWN)  ? (p2_y + 10'd2) :
                                                    p2_y;

    assign p1_in_box = display_active &&
                       (pixel_x >= p1_x) && (pixel_x < p1_x + 11'd16) &&
                       (pixel_y >= p1_y) && (pixel_y < p1_y + 10'd16);

    assign p2_in_box = display_active &&
                       (pixel_x >= p2_x) && (pixel_x < p2_x + 11'd16) &&
                       (pixel_y >= p2_y) && (pixel_y < p2_y + 10'd16);

    assign p1_local_x = pixel_x - p1_x[9:0];
    assign p1_local_y = pixel_y - p1_y;
    assign p2_local_x = pixel_x - p2_x[9:0];
    assign p2_local_y = pixel_y - p2_y;
    assign p1_effective_x = p1_x;
    assign p1_effective_y = p1_y;
    assign p2_effective_x = p2_x;
    assign p2_effective_y = p2_y;

    assign p1_bullet_in_box = p1_bullet_active && display_active &&
                              (pixel_x >= p1_bullet_x) && (pixel_x < p1_bullet_x + BULLET_SIZE_X) &&
                              (pixel_y >= p1_bullet_y) && (pixel_y < p1_bullet_y + BULLET_SIZE_Y);
    assign p1_bullet_local_x = pixel_x - p1_bullet_x[9:0];
    assign p1_bullet_local_y = pixel_y - p1_bullet_y;

    assign p2_bullet_in_box = p2_bullet_active && display_active &&
                              (pixel_x >= p2_bullet_x) && (pixel_x < p2_bullet_x + BULLET_SIZE_X) &&
                              (pixel_y >= p2_bullet_y) && (pixel_y < p2_bullet_y + BULLET_SIZE_Y);
    assign p2_bullet_local_x = pixel_x - p2_bullet_x[9:0];
    assign p2_bullet_local_y = pixel_y - p2_bullet_y;

    assign p1_bullet_spawn_x = (p1_dir == DIR_LEFT)  ? (p1_x - 11'd6)  :
                               (p1_dir == DIR_RIGHT) ? (p1_x + 11'd16) :
                                                         (p1_x + 11'd5);

    assign p1_bullet_spawn_y = (p1_dir == DIR_UP)    ? (p1_y - 10'd6)  :
                               (p1_dir == DIR_DOWN)  ? (p1_y + 10'd16) :
                                                         (p1_y + 10'd5);

    assign p2_bullet_spawn_x = (p2_dir == DIR_LEFT)  ? (p2_x - 11'd6)  :
                               (p2_dir == DIR_RIGHT) ? (p2_x + 11'd16) :
                                                         (p2_x + 11'd5);

    assign p2_bullet_spawn_y = (p2_dir == DIR_UP)    ? (p2_y - 10'd6)  :
                               (p2_dir == DIR_DOWN)  ? (p2_y + 10'd16) :
                                                         (p2_y + 10'd5);

    assign p1_bullet_next_x = (p1_bullet_dir == DIR_LEFT)  ? (p1_bullet_x - 11'd4) :
                              (p1_bullet_dir == DIR_RIGHT) ? (p1_bullet_x + 11'd4) :
                                                               p1_bullet_x;

    assign p1_bullet_next_y = (p1_bullet_dir == DIR_UP)    ? (p1_bullet_y - 10'd4) :
                              (p1_bullet_dir == DIR_DOWN)  ? (p1_bullet_y + 10'd4) :
                                                               p1_bullet_y;

    assign p2_bullet_next_x = (p2_bullet_dir == DIR_LEFT)  ? (p2_bullet_x - 11'd4) :
                              (p2_bullet_dir == DIR_RIGHT) ? (p2_bullet_x + 11'd4) :
                                                               p2_bullet_x;

    assign p2_bullet_next_y = (p2_bullet_dir == DIR_UP)    ? (p2_bullet_y - 10'd4) :
                              (p2_bullet_dir == DIR_DOWN)  ? (p2_bullet_y + 10'd4) :
                                                               p2_bullet_y;
    assign bullets_overlap_now = p1_bullet_active && p2_bullet_active &&
                                 (p1_bullet_x <= p2_bullet_x + 11'd5) &&
                                 (p1_bullet_x + 11'd5 >= p2_bullet_x) &&
                                 (p1_bullet_y <= p2_bullet_y + 10'd5) &&
                                 (p1_bullet_y + 10'd5 >= p2_bullet_y);

    assign bullets_overlap_next = p1_bullet_active && p2_bullet_active &&
                                  p1_bullet_move_ok && p2_bullet_move_ok &&
                                  (p1_bullet_next_x <= p2_bullet_next_x + 11'd5) &&
                                  (p1_bullet_next_x + 11'd5 >= p2_bullet_next_x) &&
                                  (p1_bullet_next_y <= p2_bullet_next_y + 10'd5) &&
                                  (p1_bullet_next_y + 10'd5 >= p2_bullet_next_y);

    assign p1_hit_by_p2_now = p2_bullet_active &&
                              (p2_bullet_x <= p1_effective_x + 11'd15) &&
                              (p2_bullet_x + 11'd5 >= p1_effective_x) &&
                              (p2_bullet_y <= p1_effective_y + 10'd15) &&
                              (p2_bullet_y + 10'd5 >= p1_effective_y);

    assign p1_hit_by_p2_next = p2_bullet_active && p2_bullet_move_ok &&
                               (p2_bullet_next_x <= p1_effective_x + 11'd15) &&
                               (p2_bullet_next_x + 11'd5 >= p1_effective_x) &&
                               (p2_bullet_next_y <= p1_effective_y + 10'd15) &&
                               (p2_bullet_next_y + 10'd5 >= p1_effective_y);

    assign p2_hit_by_p1_now = p1_bullet_active &&
                              (p1_bullet_x <= p2_effective_x + 11'd15) &&
                              (p1_bullet_x + 11'd5 >= p2_effective_x) &&
                              (p1_bullet_y <= p2_effective_y + 10'd15) &&
                              (p1_bullet_y + 10'd5 >= p2_effective_y);

    assign p2_hit_by_p1_next = p1_bullet_active && p1_bullet_move_ok &&
                               (p1_bullet_next_x <= p2_effective_x + 11'd15) &&
                               (p1_bullet_next_x + 11'd5 >= p2_effective_x) &&
                               (p1_bullet_next_y <= p2_effective_y + 10'd15) &&
                               (p1_bullet_next_y + 10'd5 >= p2_effective_y);
    assign p1_hit_event = p1_hit_by_p2_now | p1_hit_by_p2_next;
    assign p2_hit_event = p2_hit_by_p1_now | p2_hit_by_p1_next;

    assign explosion_now_x = ((p1_bullet_x < p2_bullet_x) ? p1_bullet_x : p2_bullet_x) - 11'd5;
    assign explosion_now_y = ((p1_bullet_y < p2_bullet_y) ? p1_bullet_y : p2_bullet_y) - 10'd5;
    assign explosion_next_x = ((p1_bullet_next_x < p2_bullet_next_x) ? p1_bullet_next_x : p2_bullet_next_x) - 11'd5;
    assign explosion_next_y = ((p1_bullet_next_y < p2_bullet_next_y) ? p1_bullet_next_y : p2_bullet_next_y) - 10'd5;

    assign explosion_in_box = explosion_active && display_active &&
                              (pixel_x >= explosion_x) && (pixel_x < explosion_x + EXPLOSION_SIZE_X) &&
                              (pixel_y >= explosion_y) && (pixel_y < explosion_y + EXPLOSION_SIZE_Y);
    assign explosion_local_x = pixel_x - explosion_x[9:0];
    assign explosion_local_y = pixel_y - explosion_y;
    assign seg_digit = seg_scan_sel ? {2'b00, p2_lives} : {2'b00, p1_lives};
    assign AN = selected ? (seg_scan_sel ? 8'b1111_1110 : 8'b0111_1111) : 8'b1111_1111;
    assign {CA, CB, CC, CD, CE, CF, CG} = selected ? seg_pattern_n : 7'b1111111;
    assign DP = 1'b1;
    assign BUZZER = selected ? buzzer_n : 1'b1;
    assign LED = selected ? {
        (game_result == RESULT_DRAW),
        game_result[1],
        game_result[0],
        title_screen,
        play_enable,
        game_over,
        ~buzzer_n,
        explosion_active,
        p2_bullet_active,
        p1_bullet_active,
        p2_lives[1],
        p2_lives[0],
        p1_lives[1],
        p1_lives[0],
        p2_fire,
        p1_fire
    } : 16'h0000;

    keyboard_dual_mapper u_keyboard_dual_mapper (
        .clk        (CLK100MHZ),
        .reset      (reset),
        .byte_ready (ps2_byte_ready),
        .byte_data  (ps2_byte_data),
        .p1_up      (p1_up),
        .p1_left    (p1_left),
        .p1_down    (p1_down),
        .p1_right   (p1_right),
        .p1_fire    (p1_fire),
        .p2_up      (p2_up),
        .p2_left    (p2_left),
        .p2_down    (p2_down),
        .p2_right   (p2_right),
        .p2_fire    (p2_fire)
    );

    move_tick_gen u_move_tick_gen (
        .clk       (CLK100MHZ),
        .reset     (reset),
        .tick_20hz (move_tick)
    );

    bullet_tick_gen u_bullet_tick_gen (
        .clk       (CLK100MHZ),
        .reset     (reset),
        .tick_40hz (bullet_tick)
    );

    map_rom u_map_rom (
        .map_id    (selected_map_id),
        .tile_x    (tile_x),
        .tile_y    (tile_y),
        .tile_type (tile_type)
    );

    tile_renderer u_tile_renderer (
        .display_active (display_active),
        .pixel_x        (pixel_x),
        .pixel_y        (pixel_y),
        .tile_type      (tile_type),
        .rgb_r          (tile_r),
        .rgb_g          (tile_g),
        .rgb_b          (tile_b)
    );

    tank_sprite u_p1_sprite (
        .local_x  (p1_local_x),
        .local_y  (p1_local_y),
        .dir      (p1_dir),
        .pixel_on (p1_pixel_on)
    );

    tank_sprite u_p2_sprite (
        .local_x  (p2_local_x),
        .local_y  (p2_local_y),
        .dir      (p2_dir),
        .pixel_on (p2_pixel_on)
    );

    bullet_sprite u_p1_bullet_sprite (
        .local_x  (p1_bullet_local_x),
        .local_y  (p1_bullet_local_y),
        .pixel_on (p1_bullet_pixel_on)
    );

    bullet_sprite u_p2_bullet_sprite (
        .local_x  (p2_bullet_local_x),
        .local_y  (p2_bullet_local_y),
        .pixel_on (p2_bullet_pixel_on)
    );

    explosion_sprite u_explosion_sprite (
        .local_x  (explosion_local_x),
        .local_y  (explosion_local_y),
        .phase    (explosion_phase),
        .pixel_on (explosion_pixel_on)
    );

    ui_overlay u_ui_overlay (
        .title_screen (title_screen),
        .menu_screen  (menu_screen),
        .map_select_screen (map_select_screen),
        .game_over    (game_over),
        .game_result  (game_result),
        .menu_index   (menu_index),
        .selected_map_id (selected_map_id),
        .map_select_idx (map_select_idx),
        .blink_on     (ui_blink_on),
        .display_active (display_active),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .pixel_on     (ui_overlay_on),
        .rgb_r        (ui_r),
        .rgb_g        (ui_g),
        .rgb_b        (ui_b)
    );

    seg7_digit_decoder u_seg7_digit_decoder (
        .digit         (seg_digit),
        .segments_low  (seg_pattern_n)
    );

    buzzer_pattern u_buzzer_pattern (
        .clk             (CLK100MHZ),
        .reset           (reset),
        .fire_event      (fire_beep_req),
        .hit_event       (hit_beep_req),
        .game_over_event (game_over_beep_req),
        .buzzer_n        (buzzer_n)
    );

    collision_check u_p1_collision_check (
        .map_id      (selected_map_id),
        .obj_x      (p1_move_check_x),
        .obj_y      (p1_move_check_y),
        .blocker_x  (p1_move_blocker_x),
        .blocker_y  (p1_move_blocker_y),
        .move_ok    (p1_move_ok)
    );

    collision_check u_p2_collision_check (
        .map_id      (selected_map_id),
        .obj_x      (p2_move_check_x),
        .obj_y      (p2_move_check_y),
        .blocker_x  (p2_move_blocker_x),
        .blocker_y  (p2_move_blocker_y),
        .move_ok    (p2_move_ok)
    );

    bullet_collision_check u_p1_bullet_collision_check (
        .map_id    (selected_map_id),
        .obj_x    (p1_bullet_next_x),
        .obj_y    (p1_bullet_next_y),
        .move_ok  (p1_bullet_move_ok)
    );

    bullet_collision_check u_p1_bullet_spawn_check (
        .map_id    (selected_map_id),
        .obj_x    (p1_bullet_spawn_x),
        .obj_y    (p1_bullet_spawn_y),
        .move_ok  (p1_bullet_spawn_ok)
    );

    bullet_collision_check u_p2_bullet_collision_check (
        .map_id    (selected_map_id),
        .obj_x    (p2_bullet_next_x),
        .obj_y    (p2_bullet_next_y),
        .move_ok  (p2_bullet_move_ok)
    );

    bullet_collision_check u_p2_bullet_spawn_check (
        .map_id    (selected_map_id),
        .obj_x    (p2_bullet_spawn_x),
        .obj_y    (p2_bullet_spawn_y),
        .move_ok  (p2_bullet_spawn_ok)
    );

    always @(*) begin
        if (ui_overlay_on) begin
            rgb_r = ui_r;
            rgb_g = ui_g;
            rgb_b = ui_b;
        end else if (explosion_in_box && explosion_pixel_on) begin
            case (explosion_phase)
                2'd0: begin
                    rgb_r = 4'hF;
                    rgb_g = 4'hF;
                    rgb_b = 4'hC;
                end
                2'd1: begin
                    rgb_r = 4'hF;
                    rgb_g = 4'hD;
                    rgb_b = 4'h4;
                end
                2'd2: begin
                    rgb_r = 4'hF;
                    rgb_g = 4'h8;
                    rgb_b = 4'h2;
                end
                default: begin
                    rgb_r = 4'hD;
                    rgb_g = 4'h4;
                    rgb_b = 4'h1;
                end
            endcase
        end else if (p1_bullet_in_box && p1_bullet_pixel_on) begin
            rgb_r = 4'hF;
            rgb_g = 4'hF;
            rgb_b = 4'h2;
        end else if (p2_bullet_in_box && p2_bullet_pixel_on) begin
            rgb_r = 4'hF;
            rgb_g = 4'hC;
            rgb_b = 4'h4;
        end else if (display_active && p1_in_box && p1_pixel_on) begin
            rgb_r = 4'h2;
            rgb_g = 4'hE;
            rgb_b = 4'hF;
        end else if (display_active && p2_in_box && p2_pixel_on) begin
            rgb_r = 4'hF;
            rgb_g = 4'h5;
            rgb_b = 4'h2;
        end else begin
            rgb_r = tile_r;
            rgb_g = tile_g;
            rgb_b = tile_b;
        end
    end

    always @(posedge CLK100MHZ) begin
        if (reset) begin
            p1_bullet_spawn_x_q <= 11'd0;
            p1_bullet_spawn_y_q <= 10'd0;
            p1_bullet_spawn_ok_q <= 1'b0;
            p2_bullet_spawn_x_q <= 11'd0;
            p2_bullet_spawn_y_q <= 10'd0;
            p2_bullet_spawn_ok_q <= 1'b0;
            p1_bullet_next_x_q <= 11'd0;
            p1_bullet_next_y_q <= 10'd0;
            p1_bullet_move_ok_q <= 1'b0;
            p2_bullet_next_x_q <= 11'd0;
            p2_bullet_next_y_q <= 10'd0;
            p2_bullet_move_ok_q <= 1'b0;
            bullets_overlap_now_q <= 1'b0;
            bullets_overlap_next_q <= 1'b0;
            p1_hit_event_q <= 1'b0;
            p2_hit_event_q <= 1'b0;
            p1_hit_explosion_x_q <= 11'd0;
            p1_hit_explosion_y_q <= 10'd0;
            p2_hit_explosion_x_q <= 11'd0;
            p2_hit_explosion_y_q <= 10'd0;
            explosion_now_x_q <= 11'd0;
            explosion_now_y_q <= 10'd0;
            explosion_next_x_q <= 11'd0;
            explosion_next_y_q <= 10'd0;
            p1_move_pending <= 1'b0;
            p2_move_pending <= 1'b0;
            p1_move_dir_q <= DIR_RIGHT;
            p2_move_dir_q <= DIR_LEFT;
            p1_move_check_x <= 11'd48;
            p1_move_check_y <= 10'd240;
            p1_move_blocker_x <= 11'd576;
            p1_move_blocker_y <= 10'd240;
            p2_move_check_x <= 11'd576;
            p2_move_check_y <= 10'd240;
            p2_move_blocker_x <= 11'd48;
            p2_move_blocker_y <= 10'd240;
        end else begin
            p1_bullet_spawn_x_q <= p1_bullet_spawn_x;
            p1_bullet_spawn_y_q <= p1_bullet_spawn_y;
            p1_bullet_spawn_ok_q <= p1_bullet_spawn_ok;
            p2_bullet_spawn_x_q <= p2_bullet_spawn_x;
            p2_bullet_spawn_y_q <= p2_bullet_spawn_y;
            p2_bullet_spawn_ok_q <= p2_bullet_spawn_ok;
            p1_bullet_next_x_q <= p1_bullet_next_x;
            p1_bullet_next_y_q <= p1_bullet_next_y;
            p1_bullet_move_ok_q <= p1_bullet_move_ok;
            p2_bullet_next_x_q <= p2_bullet_next_x;
            p2_bullet_next_y_q <= p2_bullet_next_y;
            p2_bullet_move_ok_q <= p2_bullet_move_ok;
            bullets_overlap_now_q <= bullets_overlap_now;
            bullets_overlap_next_q <= bullets_overlap_next;
            p1_hit_event_q <= p1_hit_event;
            p2_hit_event_q <= p2_hit_event;
            p1_hit_explosion_x_q <= p1_effective_x;
            p1_hit_explosion_y_q <= p1_effective_y;
            p2_hit_explosion_x_q <= p2_effective_x;
            p2_hit_explosion_y_q <= p2_effective_y;
            explosion_now_x_q <= explosion_now_x;
            explosion_now_y_q <= explosion_now_y;
            explosion_next_x_q <= explosion_next_x;
            explosion_next_y_q <= explosion_next_y;

            if (p1_move_pending) begin
                p1_move_pending <= 1'b0;
            end else if (move_tick && play_enable && p1_move_req) begin
                p1_move_pending <= 1'b1;
                p1_move_dir_q <= p1_move_dir;
                p1_move_check_x <= p1_next_x;
                p1_move_check_y <= p1_next_y;
                p1_move_blocker_x <= p2_x;
                p1_move_blocker_y <= p2_y;
            end

            if (p2_move_pending) begin
                p2_move_pending <= 1'b0;
            end else if (move_tick && play_enable && p2_move_req) begin
                p2_move_pending <= 1'b1;
                p2_move_dir_q <= p2_move_dir;
                p2_move_check_x <= p2_next_x;
                p2_move_check_y <= p2_next_y;
                p2_move_blocker_x <= p1_x;
                p2_move_blocker_y <= p1_y;
            end
        end
    end

    always @(posedge CLK100MHZ) begin
        if (reset) begin
            p1_x              <= 11'd48;
            p1_y              <= 10'd240;
            p1_dir            <= DIR_RIGHT;
            p2_x              <= 11'd576;
            p2_y              <= 10'd240;
            p2_dir            <= DIR_LEFT;
            p1_bullet_x       <= 11'd0;
            p1_bullet_y       <= 10'd0;
            p1_bullet_dir     <= DIR_RIGHT;
            p1_bullet_active  <= 1'b0;
            p1_fire_prev      <= 1'b0;
            p2_bullet_x       <= 11'd0;
            p2_bullet_y       <= 10'd0;
            p2_bullet_dir     <= DIR_LEFT;
            p2_bullet_active  <= 1'b0;
            p2_fire_prev      <= 1'b0;
            explosion_x       <= 11'd0;
            explosion_y       <= 10'd0;
            explosion_phase   <= 2'd0;
            explosion_active  <= 1'b0;
            explosion_subtick <= 1'b0;
            p1_lives          <= 2'd3;
            p2_lives          <= 2'd3;
            title_screen      <= 1'b1;
            menu_screen       <= 1'b0;
            map_select_screen <= 1'b0;
            game_over         <= 1'b0;
            game_result       <= RESULT_NONE;
            menu_index        <= 1'b0;
            selected_map_id   <= MAP_CLASSIC;
            map_select_idx    <= MAP_CLASSIC;
            fire_beep_req     <= 1'b0;
            hit_beep_req      <= 1'b0;
            game_over_beep_req <= 1'b0;
            VGA_R             <= 4'h0;
            VGA_G             <= 4'h0;
            VGA_B             <= 4'h0;
        end else begin
            p1_fire_prev <= p1_fire;
            p2_fire_prev <= p2_fire;
            fire_beep_req <= 1'b0;
            hit_beep_req <= 1'b0;
            game_over_beep_req <= 1'b0;

            if (title_screen) begin
                if (nav_fire_pulse) begin
                    title_screen <= 1'b0;
                    menu_screen <= 1'b1;
                    fire_beep_req <= 1'b1;
                end
            end else if (menu_screen) begin
                if (move_tick && (nav_up | nav_down | nav_left | nav_right)) begin
                    menu_index <= ~menu_index;
                end

                if (nav_fire_pulse) begin
                    fire_beep_req <= 1'b1;
                    if (!menu_index) begin
                        p1_x              <= spawn_p1_x;
                        p1_y              <= spawn_p1_y;
                        p1_dir            <= spawn_p1_dir;
                        p2_x              <= spawn_p2_x;
                        p2_y              <= spawn_p2_y;
                        p2_dir            <= spawn_p2_dir;
                        p1_bullet_x       <= 11'd0;
                        p1_bullet_y       <= 10'd0;
                        p1_bullet_dir     <= spawn_p1_dir;
                        p1_bullet_active  <= 1'b0;
                        p2_bullet_x       <= 11'd0;
                        p2_bullet_y       <= 10'd0;
                        p2_bullet_dir     <= spawn_p2_dir;
                        p2_bullet_active  <= 1'b0;
                        explosion_x       <= 11'd0;
                        explosion_y       <= 10'd0;
                        explosion_phase   <= 2'd0;
                        explosion_active  <= 1'b0;
                        explosion_subtick <= 1'b0;
                        p1_lives          <= 2'd3;
                        p2_lives          <= 2'd3;
                        game_over         <= 1'b0;
                        game_result       <= RESULT_NONE;
                        menu_screen       <= 1'b0;
                    end else begin
                        menu_screen <= 1'b0;
                        map_select_screen <= 1'b1;
                        map_select_idx <= selected_map_id;
                    end
                end
            end else if (map_select_screen) begin
                if (move_tick) begin
                    if (nav_up && (map_select_idx >= 3'd3))
                        map_select_idx <= map_select_idx - 3'd3;
                    else if (nav_down && (map_select_idx <= 3'd2))
                        map_select_idx <= map_select_idx + 3'd3;
                    else if (nav_left && (map_select_idx != 3'd0) && (map_select_idx != 3'd3))
                        map_select_idx <= map_select_idx - 3'd1;
                    else if (nav_right && (map_select_idx != 3'd2) && (map_select_idx != 3'd5))
                        map_select_idx <= map_select_idx + 3'd1;
                end

                if (nav_fire_pulse) begin
                    selected_map_id <= map_select_idx;
                    map_select_screen <= 1'b0;
                    menu_screen <= 1'b1;
                    fire_beep_req <= 1'b1;
                end
            end else if (game_over) begin
                if (nav_fire_pulse) begin
                    game_over <= 1'b0;
                    game_result <= RESULT_NONE;
                    menu_screen <= 1'b1;
                    fire_beep_req <= 1'b1;
                end
            end else if (play_enable) begin
                if (p1_move_pending) begin
                    p1_dir <= p1_move_dir_q;
                    if (p1_move_ok) begin
                        p1_x <= p1_move_check_x;
                        p1_y <= p1_move_check_y;
                    end
                end

                if (p2_move_pending) begin
                    p2_dir <= p2_move_dir_q;
                    if (p2_move_ok) begin
                        p2_x <= p2_move_check_x;
                        p2_y <= p2_move_check_y;
                    end
                end

                if (p1_fire_pulse && p1_bullet_spawn_ok_q) begin
                    p1_bullet_x <= p1_bullet_spawn_x_q;
                    p1_bullet_y <= p1_bullet_spawn_y_q;
                    p1_bullet_dir <= p1_dir;
                    p1_bullet_active <= 1'b1;
                    fire_beep_req <= 1'b1;
                end else if (bullet_tick && p1_bullet_active) begin
                    if (p1_bullet_move_ok_q) begin
                        p1_bullet_x <= p1_bullet_next_x_q;
                        p1_bullet_y <= p1_bullet_next_y_q;
                    end else begin
                        p1_bullet_active <= 1'b0;
                    end
                end

                if (p2_fire_pulse && p2_bullet_spawn_ok_q) begin
                    p2_bullet_x <= p2_bullet_spawn_x_q;
                    p2_bullet_y <= p2_bullet_spawn_y_q;
                    p2_bullet_dir <= p2_dir;
                    p2_bullet_active <= 1'b1;
                    fire_beep_req <= 1'b1;
                end else if (bullet_tick && p2_bullet_active) begin
                    if (p2_bullet_move_ok_q) begin
                        p2_bullet_x <= p2_bullet_next_x_q;
                        p2_bullet_y <= p2_bullet_next_y_q;
                    end else begin
                        p2_bullet_active <= 1'b0;
                    end
                end

                if (bullet_tick) begin
                    if (bullets_overlap_now_q) begin
                        p1_bullet_active <= 1'b0;
                        p2_bullet_active <= 1'b0;
                        explosion_x <= explosion_now_x_q;
                        explosion_y <= explosion_now_y_q;
                        explosion_phase <= 2'd0;
                        explosion_active <= 1'b1;
                        explosion_subtick <= 1'b0;
                    end else if (!p1_fire_pulse && !p2_fire_pulse && bullets_overlap_next_q) begin
                        p1_bullet_active <= 1'b0;
                        p2_bullet_active <= 1'b0;
                        explosion_x <= explosion_next_x_q;
                        explosion_y <= explosion_next_y_q;
                        explosion_phase <= 2'd0;
                        explosion_active <= 1'b1;
                        explosion_subtick <= 1'b0;
                    end else if (p1_hit_event_q || p2_hit_event_q) begin
                        hit_beep_req <= 1'b1;

                        if (p1_hit_event_q && (p1_lives != 2'd0))
                            p1_lives <= p1_lives - 2'd1;

                        if (p2_hit_event_q && (p2_lives != 2'd0))
                            p2_lives <= p2_lives - 2'd1;

                        if ((p1_hit_event_q && (p1_lives == 2'd1)) ||
                            (p2_hit_event_q && (p2_lives == 2'd1))) begin
                            game_over <= 1'b1;
                            game_over_beep_req <= 1'b1;

                            if (p1_hit_event_q && (p1_lives == 2'd1) &&
                                p2_hit_event_q && (p2_lives == 2'd1))
                                game_result <= RESULT_DRAW;
                            else if (p2_hit_event_q && (p2_lives == 2'd1))
                                game_result <= RESULT_P1;
                            else
                                game_result <= RESULT_P2;
                        end

                        p1_x <= spawn_p1_x;
                        p1_y <= spawn_p1_y;
                        p1_dir <= spawn_p1_dir;
                        p2_x <= spawn_p2_x;
                        p2_y <= spawn_p2_y;
                        p2_dir <= spawn_p2_dir;
                        p1_bullet_active <= 1'b0;
                        p2_bullet_active <= 1'b0;
                        if (p1_hit_event_q) begin
                            explosion_x <= p1_hit_explosion_x_q;
                            explosion_y <= p1_hit_explosion_y_q;
                        end else begin
                            explosion_x <= p2_hit_explosion_x_q;
                            explosion_y <= p2_hit_explosion_y_q;
                        end
                        explosion_phase <= 2'd0;
                        explosion_active <= 1'b1;
                        explosion_subtick <= 1'b0;
                    end else if (explosion_active) begin
                        if (!explosion_subtick) begin
                            explosion_subtick <= 1'b1;
                        end else begin
                            explosion_subtick <= 1'b0;
                            if (explosion_phase == 2'd3) begin
                                explosion_active <= 1'b0;
                            end else begin
                                explosion_phase <= explosion_phase + 2'd1;
                            end
                        end
                    end
                end
            end
        end

        if (reset) begin
            VGA_R  <= 4'h0;
            VGA_G  <= 4'h0;
            VGA_B  <= 4'h0;
        end else if (pixel_tick) begin
            VGA_R <= rgb_r;
            VGA_G <= rgb_g;
            VGA_B <= rgb_b;
        end
    end

    always @(posedge CLK100MHZ) begin
        if (reset) begin
            seg_refresh_counter <= 17'd0;
            seg_scan_sel <= 1'b0;
        end else if (seg_refresh_counter == SEG_REFRESH_DIV - 1) begin
            seg_refresh_counter <= 17'd0;
            seg_scan_sel <= ~seg_scan_sel;
        end else begin
            seg_refresh_counter <= seg_refresh_counter + 17'd1;
        end
    end

    always @(posedge CLK100MHZ) begin
        if (reset) begin
            ui_blink_counter <= 26'd0;
        end else begin
            ui_blink_counter <= ui_blink_counter + 26'd1;
        end
    end

endmodule

module bullet_sprite (
    input  wire [3:0] local_x,
    input  wire [3:0] local_y,
    output reg        pixel_on
);

    always @(*) begin
        pixel_on = 1'b0;

        if (((local_x >= 4'd2) && (local_x <= 4'd3) && (local_y <= 4'd5)) ||
            ((local_y >= 4'd2) && (local_y <= 4'd3) && (local_x <= 4'd5))) begin
            pixel_on = 1'b1;
        end
    end

endmodule

module explosion_sprite (
    input  wire [3:0] local_x,
    input  wire [3:0] local_y,
    input  wire [1:0] phase,
    output reg        pixel_on
);

    always @(*) begin
        pixel_on = 1'b0;

        case (phase)
            2'd0: begin
                if (((local_x >= 4'd6) && (local_x <= 4'd9) && (local_y >= 4'd4) && (local_y <= 4'd11)) ||
                    ((local_y >= 4'd6) && (local_y <= 4'd9) && (local_x >= 4'd4) && (local_x <= 4'd11)) ||
                    ((local_x >= 4'd6) && (local_x <= 4'd9) && (local_y >= 4'd6) && (local_y <= 4'd9)))
                    pixel_on = 1'b1;
            end

            2'd1: begin
                if (((local_x >= 4'd6) && (local_x <= 4'd9) && (local_y >= 4'd2) && (local_y <= 4'd13)) ||
                    ((local_y >= 4'd6) && (local_y <= 4'd9) && (local_x >= 4'd2) && (local_x <= 4'd13)) ||
                    ((local_x >= 4'd3) && (local_x <= 4'd4) && (local_y >= 4'd3) && (local_y <= 4'd4)) ||
                    ((local_x >= 4'd11) && (local_x <= 4'd12) && (local_y >= 4'd3) && (local_y <= 4'd4)) ||
                    ((local_x >= 4'd3) && (local_x <= 4'd4) && (local_y >= 4'd11) && (local_y <= 4'd12)) ||
                    ((local_x >= 4'd11) && (local_x <= 4'd12) && (local_y >= 4'd11) && (local_y <= 4'd12)))
                    pixel_on = 1'b1;
            end

            2'd2: begin
                if (((local_x >= 4'd7) && (local_x <= 4'd8) && (local_y >= 4'd1) && (local_y <= 4'd14)) ||
                    ((local_y >= 4'd7) && (local_y <= 4'd8) && (local_x >= 4'd1) && (local_x <= 4'd14)) ||
                    ((local_x >= 4'd2) && (local_x <= 4'd3) && (local_y >= 4'd2) && (local_y <= 4'd3)) ||
                    ((local_x >= 4'd12) && (local_x <= 4'd13) && (local_y >= 4'd2) && (local_y <= 4'd3)) ||
                    ((local_x >= 4'd2) && (local_x <= 4'd3) && (local_y >= 4'd12) && (local_y <= 4'd13)) ||
                    ((local_x >= 4'd12) && (local_x <= 4'd13) && (local_y >= 4'd12) && (local_y <= 4'd13)))
                    pixel_on = 1'b1;
            end

            default: begin
                if (((local_x >= 4'd1) && (local_x <= 4'd2) && (local_y >= 4'd1) && (local_y <= 4'd2)) ||
                    ((local_x >= 4'd13) && (local_x <= 4'd14) && (local_y >= 4'd1) && (local_y <= 4'd2)) ||
                    ((local_x >= 4'd1) && (local_x <= 4'd2) && (local_y >= 4'd13) && (local_y <= 4'd14)) ||
                    ((local_x >= 4'd13) && (local_x <= 4'd14) && (local_y >= 4'd13) && (local_y <= 4'd14)) ||
                    ((local_x >= 4'd7) && (local_x <= 4'd8) && (local_y >= 4'd0) && (local_y <= 4'd1)) ||
                    ((local_x >= 4'd7) && (local_x <= 4'd8) && (local_y >= 4'd14) && (local_y <= 4'd15)) ||
                    ((local_y >= 4'd7) && (local_y <= 4'd8) && (local_x >= 4'd0) && (local_x <= 4'd1)) ||
                    ((local_y >= 4'd7) && (local_y <= 4'd8) && (local_x >= 4'd14) && (local_x <= 4'd15)))
                    pixel_on = 1'b1;
            end
        endcase
    end

endmodule

module map_thumb_renderer (
    input  wire [2:0] map_id,
    input  wire       selected,
    input  wire       display_active,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire [9:0] origin_x,
    input  wire [9:0] origin_y,
    output reg        pixel_on,
    output reg  [3:0] rgb_r,
    output reg  [3:0] rgb_g,
    output reg  [3:0] rgb_b
);

    wire in_map_box;
    wire in_border_box;
    wire [5:0] tile_x;
    wire [4:0] tile_y;
    wire [1:0] tile_type;
    wire [6:0] local_x;
    wire [6:0] local_y;

    assign in_map_box = (pixel_x >= origin_x) && (pixel_x < origin_x + 10'd80) &&
                        (pixel_y >= origin_y) && (pixel_y < origin_y + 10'd60);
    assign in_border_box = (pixel_x >= origin_x - 10'd2) && (pixel_x < origin_x + 10'd82) &&
                           (pixel_y >= origin_y - 10'd2) && (pixel_y < origin_y + 10'd62);
    assign local_x = pixel_x - origin_x;
    assign local_y = pixel_y - origin_y;
    assign tile_x = local_x[6:1];
    assign tile_y = local_y[5:1];

    map_rom thumb_map (
        .map_id    (map_id),
        .tile_x    (tile_x),
        .tile_y    (tile_y),
        .tile_type (tile_type)
    );

    always @(*) begin
        pixel_on = 1'b0;
        rgb_r = 4'h0;
        rgb_g = 4'h0;
        rgb_b = 4'h0;

        if (display_active && in_border_box &&
            ((pixel_x == origin_x - 10'd2) || (pixel_x == origin_x + 10'd81) ||
             (pixel_y == origin_y - 10'd2) || (pixel_y == origin_y + 10'd61) ||
             (pixel_x == origin_x - 10'd1) || (pixel_x == origin_x + 10'd80) ||
             (pixel_y == origin_y - 10'd1) || (pixel_y == origin_y + 10'd60))) begin
            pixel_on = 1'b1;
            if (selected) begin
                rgb_r = 4'hF;
                rgb_g = 4'hD;
                rgb_b = 4'h4;
            end else begin
                rgb_r = 4'h5;
                rgb_g = 4'h7;
                rgb_b = 4'h8;
            end
        end else if (display_active && in_map_box) begin
            pixel_on = 1'b1;
            case (tile_type)
                2'b01: begin
                    rgb_r = 4'h8;
                    rgb_g = 4'h9;
                    rgb_b = 4'hB;
                end
                2'b10: begin
                    rgb_r = 4'hC;
                    rgb_g = 4'h5;
                    rgb_b = 4'h2;
                end
                default: begin
                    rgb_r = 4'h1;
                    rgb_g = 4'h4;
                    rgb_b = 4'h1;
                end
            endcase

            if ((local_x[0] == 1'b0) || (local_y[0] == 1'b0)) begin
                rgb_r = rgb_r >> 1;
                rgb_g = rgb_g >> 1;
                rgb_b = rgb_b >> 1;
            end
        end
    end

endmodule

module ui_overlay (
    input  wire       title_screen,
    input  wire       menu_screen,
    input  wire       map_select_screen,
    input  wire       game_over,
    input  wire [1:0] game_result,
    input  wire       menu_index,
    input  wire [2:0] selected_map_id,
    input  wire [2:0] map_select_idx,
    input  wire       blink_on,
    input  wire       display_active,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    output reg        pixel_on,
    output reg  [3:0] rgb_r,
    output reg  [3:0] rgb_g,
    output reg  [3:0] rgb_b
);

    localparam [2:0] MAP_CLASSIC  = 3'd0;
    localparam [2:0] MAP_LANES    = 3'd1;
    localparam [2:0] MAP_FORTRESS = 3'd2;
    localparam [2:0] MAP_MAZE     = 3'd3;
    localparam [2:0] MAP_OPEN     = 3'd4;
    localparam [2:0] MAP_QUAD     = 3'd5;
    localparam [1:0] RESULT_P1   = 2'd1;
    localparam [1:0] RESULT_P2   = 2'd2;
    localparam [1:0] RESULT_DRAW = 2'd3;

    wire thumb0_on, thumb1_on, thumb2_on, thumb3_on, thumb4_on, thumb5_on;
    wire [3:0] thumb0_r, thumb0_g, thumb0_b;
    wire [3:0] thumb1_r, thumb1_g, thumb1_b;
    wire [3:0] thumb2_r, thumb2_g, thumb2_b;
    wire [3:0] thumb3_r, thumb3_g, thumb3_b;
    wire [3:0] thumb4_r, thumb4_g, thumb4_b;
    wire [3:0] thumb5_r, thumb5_g, thumb5_b;

    reg [7:0] char_code;
    reg [7:0] row_bits;
    reg [2:0] font_row;
    reg [2:0] font_col;
    reg [4:0] char_idx;
    reg       text_hit;

    map_thumb_renderer thumb0 (
        .map_id(MAP_CLASSIC), .selected(map_select_idx == 3'd0), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd70), .origin_y(10'd120),
        .pixel_on(thumb0_on), .rgb_r(thumb0_r), .rgb_g(thumb0_g), .rgb_b(thumb0_b)
    );
    map_thumb_renderer thumb1 (
        .map_id(MAP_LANES), .selected(map_select_idx == 3'd1), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd280), .origin_y(10'd120),
        .pixel_on(thumb1_on), .rgb_r(thumb1_r), .rgb_g(thumb1_g), .rgb_b(thumb1_b)
    );
    map_thumb_renderer thumb2 (
        .map_id(MAP_FORTRESS), .selected(map_select_idx == 3'd2), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd490), .origin_y(10'd120),
        .pixel_on(thumb2_on), .rgb_r(thumb2_r), .rgb_g(thumb2_g), .rgb_b(thumb2_b)
    );
    map_thumb_renderer thumb3 (
        .map_id(MAP_MAZE), .selected(map_select_idx == 3'd3), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd70), .origin_y(10'd280),
        .pixel_on(thumb3_on), .rgb_r(thumb3_r), .rgb_g(thumb3_g), .rgb_b(thumb3_b)
    );
    map_thumb_renderer thumb4 (
        .map_id(MAP_OPEN), .selected(map_select_idx == 3'd4), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd280), .origin_y(10'd280),
        .pixel_on(thumb4_on), .rgb_r(thumb4_r), .rgb_g(thumb4_g), .rgb_b(thumb4_b)
    );
    map_thumb_renderer thumb5 (
        .map_id(MAP_QUAD), .selected(map_select_idx == 3'd5), .display_active(display_active),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .origin_x(10'd490), .origin_y(10'd280),
        .pixel_on(thumb5_on), .rgb_r(thumb5_r), .rgb_g(thumb5_g), .rgb_b(thumb5_b)
    );

    function [7:0] title_char;
        input [4:0] idx;
        begin
            case (idx)
                5'd0: title_char = "T";
                5'd1: title_char = "A";
                5'd2: title_char = "N";
                5'd3: title_char = "K";
                5'd4: title_char = " ";
                5'd5: title_char = "W";
                5'd6: title_char = "A";
                5'd7: title_char = "R";
                default: title_char = " ";
            endcase
        end
    endfunction

    function [7:0] prompt_char;
        input [4:0] idx;
        begin
            case (idx)
                5'd0: prompt_char = "P";
                5'd1: prompt_char = "R";
                5'd2: prompt_char = "E";
                5'd3: prompt_char = "S";
                5'd4: prompt_char = "S";
                5'd5: prompt_char = " ";
                5'd6: prompt_char = "F";
                5'd7: prompt_char = "I";
                5'd8: prompt_char = "R";
                5'd9: prompt_char = "E";
                default: prompt_char = " ";
            endcase
        end
    endfunction

    function [7:0] menu_char;
        input [0:0] line_id;
        input [4:0] idx;
        begin
            case (line_id)
                1'b0: begin
                    case (idx)
                        5'd0: menu_char = "S";
                        5'd1: menu_char = "T";
                        5'd2: menu_char = "A";
                        5'd3: menu_char = "R";
                        5'd4: menu_char = "T";
                        5'd5: menu_char = " ";
                        5'd6: menu_char = "G";
                        5'd7: menu_char = "A";
                        5'd8: menu_char = "M";
                        5'd9: menu_char = "E";
                        default: menu_char = " ";
                    endcase
                end
                default: begin
                    case (idx)
                        5'd0: menu_char = "S";
                        5'd1: menu_char = "E";
                        5'd2: menu_char = "L";
                        5'd3: menu_char = "E";
                        5'd4: menu_char = "C";
                        5'd5: menu_char = "T";
                        5'd6: menu_char = " ";
                        5'd7: menu_char = "M";
                        5'd8: menu_char = "A";
                        5'd9: menu_char = "P";
                        default: menu_char = " ";
                    endcase
                end
            endcase
        end
    endfunction

    function [7:0] map_name_char;
        input [2:0] map_id;
        input [4:0] idx;
        begin
            case (map_id)
                3'd0: begin
                    case (idx)
                        5'd0: map_name_char = "C";
                        5'd1: map_name_char = "L";
                        5'd2: map_name_char = "A";
                        5'd3: map_name_char = "S";
                        5'd4: map_name_char = "S";
                        5'd5: map_name_char = "I";
                        5'd6: map_name_char = "C";
                        default: map_name_char = " ";
                    endcase
                end
                3'd1: begin
                    case (idx)
                        5'd0: map_name_char = "L";
                        5'd1: map_name_char = "A";
                        5'd2: map_name_char = "N";
                        5'd3: map_name_char = "E";
                        5'd4: map_name_char = "S";
                        default: map_name_char = " ";
                    endcase
                end
                3'd2: begin
                    case (idx)
                        5'd0: map_name_char = "F";
                        5'd1: map_name_char = "O";
                        5'd2: map_name_char = "R";
                        5'd3: map_name_char = "T";
                        default: map_name_char = " ";
                    endcase
                end
                3'd3: begin
                    case (idx)
                        5'd0: map_name_char = "M";
                        5'd1: map_name_char = "A";
                        5'd2: map_name_char = "Z";
                        5'd3: map_name_char = "E";
                        default: map_name_char = " ";
                    endcase
                end
                3'd4: begin
                    case (idx)
                        5'd0: map_name_char = "O";
                        5'd1: map_name_char = "P";
                        5'd2: map_name_char = "E";
                        5'd3: map_name_char = "N";
                        default: map_name_char = " ";
                    endcase
                end
                default: begin
                    case (idx)
                        5'd0: map_name_char = "Q";
                        5'd1: map_name_char = "U";
                        5'd2: map_name_char = "A";
                        5'd3: map_name_char = "D";
                        default: map_name_char = " ";
                    endcase
                end
            endcase
        end
    endfunction

    function [7:0] result_char;
        input [1:0] line_id;
        input [4:0] idx;
        input [1:0] result_id;
        begin
            case (line_id)
                2'd0: begin
                    case (idx)
                        5'd0: result_char = "G";
                        5'd1: result_char = "A";
                        5'd2: result_char = "M";
                        5'd3: result_char = "E";
                        5'd4: result_char = " ";
                        5'd5: result_char = "O";
                        5'd6: result_char = "V";
                        5'd7: result_char = "E";
                        5'd8: result_char = "R";
                        default: result_char = " ";
                    endcase
                end
                2'd1: begin
                    case (result_id)
                        RESULT_P1: begin
                            case (idx)
                                5'd0: result_char = "P";
                                5'd1: result_char = "1";
                                5'd2: result_char = " ";
                                5'd3: result_char = "W";
                                5'd4: result_char = "I";
                                5'd5: result_char = "N";
                                default: result_char = " ";
                            endcase
                        end
                        RESULT_P2: begin
                            case (idx)
                                5'd0: result_char = "P";
                                5'd1: result_char = "2";
                                5'd2: result_char = " ";
                                5'd3: result_char = "W";
                                5'd4: result_char = "I";
                                5'd5: result_char = "N";
                                default: result_char = " ";
                            endcase
                        end
                        default: begin
                            case (idx)
                                5'd0: result_char = "D";
                                5'd1: result_char = "R";
                                5'd2: result_char = "A";
                                5'd3: result_char = "W";
                                default: result_char = " ";
                            endcase
                        end
                    endcase
                end
                default: begin
                    result_char = prompt_char(idx);
                end
            endcase
        end
    endfunction

    function [7:0] font_bits;
        input [7:0] ch;
        input [2:0] row;
        begin
            case (ch)
                " ": font_bits = 8'b00000000;
                "1": case (row) 3'd0:font_bits=8'b00011000; 3'd1:font_bits=8'b00111000; 3'd2:font_bits=8'b00011000; 3'd3:font_bits=8'b00011000; 3'd4:font_bits=8'b00011000; 3'd5:font_bits=8'b00011000; default:font_bits=8'b00111100; endcase
                "2": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b00000110; 3'd3:font_bits=8'b00001100; 3'd4:font_bits=8'b00110000; 3'd5:font_bits=8'b01100000; default:font_bits=8'b01111110; endcase
                "A": case (row) 3'd0:font_bits=8'b00011000; 3'd1:font_bits=8'b00111100; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01111110; default:font_bits=8'b01100110; endcase
                "C": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b01100000; 3'd4:font_bits=8'b01100000; 3'd5:font_bits=8'b01100110; default:font_bits=8'b00111100; endcase
                "D": case (row) 3'd0:font_bits=8'b01111000; 3'd1:font_bits=8'b01101100; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01100110; 3'd5:font_bits=8'b01101100; default:font_bits=8'b01111000; endcase
                "E": case (row) 3'd0:font_bits=8'b01111110; 3'd1:font_bits=8'b01100000; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b01111100; 3'd4:font_bits=8'b01100000; 3'd5:font_bits=8'b01100000; default:font_bits=8'b01111110; endcase
                "F": case (row) 3'd0:font_bits=8'b01111110; 3'd1:font_bits=8'b01100000; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b01111100; default:font_bits=8'b01100000; endcase
                "G": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b01101110; 3'd4:font_bits=8'b01100110; 3'd5:font_bits=8'b01100110; default:font_bits=8'b00111110; endcase
                "I": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b00011000; 3'd2:font_bits=8'b00011000; 3'd3:font_bits=8'b00011000; 3'd4:font_bits=8'b00011000; 3'd5:font_bits=8'b00011000; default:font_bits=8'b00111100; endcase
                "K": case (row) 3'd0:font_bits=8'b01100110; 3'd1:font_bits=8'b01101100; 3'd2:font_bits=8'b01111000; 3'd3:font_bits=8'b01110000; 3'd4:font_bits=8'b01111000; 3'd5:font_bits=8'b01101100; default:font_bits=8'b01100110; endcase
                "L": case (row) 3'd0:font_bits=8'b01100000; 3'd1:font_bits=8'b01100000; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b01100000; 3'd4:font_bits=8'b01100000; 3'd5:font_bits=8'b01100000; default:font_bits=8'b01111110; endcase
                "M": case (row) 3'd0:font_bits=8'b01100011; 3'd1:font_bits=8'b01110111; 3'd2:font_bits=8'b01111111; 3'd3:font_bits=8'b01101011; default:font_bits=8'b01100011; endcase
                "N": case (row) 3'd0:font_bits=8'b01100110; 3'd1:font_bits=8'b01110110; 3'd2:font_bits=8'b01111110; 3'd3:font_bits=8'b01111110; 3'd4:font_bits=8'b01101110; default:font_bits=8'b01100110; endcase
                "O": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01100110; 3'd5:font_bits=8'b01100110; default:font_bits=8'b00111100; endcase
                "P": case (row) 3'd0:font_bits=8'b01111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01111100; default:font_bits=8'b01100000; endcase
                "Q": case (row) 3'd0:font_bits=8'b00111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01101110; 3'd5:font_bits=8'b00111100; default:font_bits=8'b00000110; endcase
                "R": case (row) 3'd0:font_bits=8'b01111100; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01111100; 3'd4:font_bits=8'b01111000; 3'd5:font_bits=8'b01101100; default:font_bits=8'b01100110; endcase
                "S": case (row) 3'd0:font_bits=8'b00111110; 3'd1:font_bits=8'b01100000; 3'd2:font_bits=8'b01100000; 3'd3:font_bits=8'b00111100; 3'd4:font_bits=8'b00000110; 3'd5:font_bits=8'b00000110; default:font_bits=8'b01111100; endcase
                "T": case (row) 3'd0:font_bits=8'b01111110; 3'd1:font_bits=8'b01011010; 3'd2:font_bits=8'b00011000; 3'd3:font_bits=8'b00011000; 3'd4:font_bits=8'b00011000; 3'd5:font_bits=8'b00011000; default:font_bits=8'b00111100; endcase
                "U": case (row) 3'd0:font_bits=8'b01100110; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01100110; 3'd5:font_bits=8'b01100110; default:font_bits=8'b00111100; endcase
                "V": case (row) 3'd0:font_bits=8'b01100110; 3'd1:font_bits=8'b01100110; 3'd2:font_bits=8'b01100110; 3'd3:font_bits=8'b01100110; 3'd4:font_bits=8'b01100110; 3'd5:font_bits=8'b00111100; default:font_bits=8'b00011000; endcase
                "W": case (row) 3'd0:font_bits=8'b01100011; 3'd1:font_bits=8'b01100011; 3'd2:font_bits=8'b01100011; 3'd3:font_bits=8'b01101011; 3'd4:font_bits=8'b01111111; 3'd5:font_bits=8'b01110111; default:font_bits=8'b01100011; endcase
                "Z": case (row) 3'd0:font_bits=8'b01111110; 3'd1:font_bits=8'b00000110; 3'd2:font_bits=8'b00001100; 3'd3:font_bits=8'b00011000; 3'd4:font_bits=8'b00110000; 3'd5:font_bits=8'b01100000; default:font_bits=8'b01111110; endcase
                default: font_bits = 8'b00000000;
            endcase
        end
    endfunction

    task draw_text;
        input [9:0] base_x;
        input [9:0] base_y;
        input [3:0] color_r;
        input [3:0] color_g;
        input [3:0] color_b;
        input [7:0] ch;
        begin
            if ((pixel_x >= base_x) && (pixel_x < base_x + 10'd32) &&
                (pixel_y >= base_y) && (pixel_y < base_y + 10'd32)) begin
                font_row = (pixel_y - base_y) >> 2;
                font_col = ((pixel_x - base_x) >> 2) & 3'b111;
                row_bits = font_bits(ch, font_row);
                if (row_bits[7 - font_col]) begin
                    rgb_r = color_r;
                    rgb_g = color_g;
                    rgb_b = color_b;
                end
            end
        end
    endtask

    always @(*) begin
        pixel_on = 1'b0;
        rgb_r = 4'h0;
        rgb_g = 4'h0;
        rgb_b = 4'h0;
        char_code = " ";
        row_bits = 8'h00;
        font_row = 3'd0;
        font_col = 3'd0;
        char_idx = 5'd0;
        text_hit = 1'b0;

        if (!display_active) begin
            pixel_on = 1'b0;
        end else if (title_screen || menu_screen || map_select_screen || game_over) begin
            pixel_on = 1'b1;
            rgb_r = 4'h0;
            rgb_g = 4'h1;
            rgb_b = 4'h2;

            if (title_screen) begin
                rgb_r = 4'h0;
                rgb_g = 4'h1;
                rgb_b = 4'h4;
                if ((pixel_x >= 10'd72) && (pixel_x <= 10'd567) &&
                    (pixel_y >= 10'd72) && (pixel_y <= 10'd407)) begin
                    rgb_r = 4'h0;
                    rgb_g = 4'h2;
                    rgb_b = 4'h6;
                end
                if ((pixel_x == 10'd72) || (pixel_x == 10'd567) ||
                    (pixel_y == 10'd72) || (pixel_y == 10'd407)) begin
                    rgb_r = 4'h3;
                    rgb_g = 4'hC;
                    rgb_b = 4'hF;
                end
                for (char_idx = 0; char_idx < 8; char_idx = char_idx + 1)
                    draw_text(10'd192 + (char_idx << 5), 10'd128, 4'hF, 4'hD, 4'h4, title_char(char_idx));
                if (blink_on)
                    for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                        draw_text(10'd160 + (char_idx << 5), 10'd256, 4'hF, 4'hF, 4'hF, prompt_char(char_idx));
            end else if (menu_screen) begin
                rgb_r = 4'h0;
                rgb_g = 4'h2;
                rgb_b = 4'h3;
                if ((pixel_x == 10'd96) || (pixel_x == 10'd543) ||
                    (pixel_y == 10'd80) || (pixel_y == 10'd399)) begin
                    rgb_r = 4'h6;
                    rgb_g = 4'hB;
                    rgb_b = 4'hD;
                end
                for (char_idx = 0; char_idx < 8; char_idx = char_idx + 1)
                    draw_text(10'd192 + (char_idx << 5), 10'd112, 4'hF, 4'hD, 4'h4, title_char(char_idx));

                if (!menu_index &&
                    (pixel_x >= 10'd176) && (pixel_x <= 10'd463) &&
                    (pixel_y >= 10'd212) && (pixel_y <= 10'd251)) begin
                    rgb_r = 4'h1;
                    rgb_g = 4'h6;
                    rgb_b = 4'h8;
                end
                if (menu_index &&
                    (pixel_x >= 10'd176) && (pixel_x <= 10'd463) &&
                    (pixel_y >= 10'd276) && (pixel_y <= 10'd315)) begin
                    rgb_r = 4'h8;
                    rgb_g = 4'h4;
                    rgb_b = 4'h1;
                end

                for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                    draw_text(10'd176 + (char_idx << 5), 10'd216, (!menu_index ? 4'hF : 4'hA), (!menu_index ? 4'hF : 4'hC), (!menu_index ? 4'hC : 4'hA), menu_char(1'b0, char_idx));
                for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                    draw_text(10'd176 + (char_idx << 5), 10'd280, (menu_index ? 4'hF : 4'hA), (menu_index ? 4'hD : 4'hC), (menu_index ? 4'h4 : 4'hA), menu_char(1'b1, char_idx));
            end else if (map_select_screen) begin
                rgb_r = 4'h0;
                rgb_g = 4'h1;
                rgb_b = 4'h1;

                for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                    draw_text(10'd144 + (char_idx << 5), 10'd40, 4'hF, 4'hE, 4'hD, menu_char(1'b1, char_idx));

                if (thumb0_on) begin rgb_r = thumb0_r; rgb_g = thumb0_g; rgb_b = thumb0_b; end
                if (thumb1_on) begin rgb_r = thumb1_r; rgb_g = thumb1_g; rgb_b = thumb1_b; end
                if (thumb2_on) begin rgb_r = thumb2_r; rgb_g = thumb2_g; rgb_b = thumb2_b; end
                if (thumb3_on) begin rgb_r = thumb3_r; rgb_g = thumb3_g; rgb_b = thumb3_b; end
                if (thumb4_on) begin rgb_r = thumb4_r; rgb_g = thumb4_g; rgb_b = thumb4_b; end
                if (thumb5_on) begin rgb_r = thumb5_r; rgb_g = thumb5_g; rgb_b = thumb5_b; end

                for (char_idx = 0; char_idx < 7; char_idx = char_idx + 1)
                    draw_text(10'd54 + (char_idx << 5), 10'd190, (selected_map_id == 3'd0 ? 4'hF : 4'hB), (selected_map_id == 3'd0 ? 4'hD : 4'hB), (selected_map_id == 3'd0 ? 4'h4 : 4'hB), map_name_char(3'd0, char_idx));
                for (char_idx = 0; char_idx < 5; char_idx = char_idx + 1)
                    draw_text(10'd280 + (char_idx << 5), 10'd190, (selected_map_id == 3'd1 ? 4'hF : 4'hB), (selected_map_id == 3'd1 ? 4'hD : 4'hB), (selected_map_id == 3'd1 ? 4'h4 : 4'hB), map_name_char(3'd1, char_idx));
                for (char_idx = 0; char_idx < 4; char_idx = char_idx + 1)
                    draw_text(10'd506 + (char_idx << 5), 10'd190, (selected_map_id == 3'd2 ? 4'hF : 4'hB), (selected_map_id == 3'd2 ? 4'hD : 4'hB), (selected_map_id == 3'd2 ? 4'h4 : 4'hB), map_name_char(3'd2, char_idx));
                for (char_idx = 0; char_idx < 4; char_idx = char_idx + 1)
                    draw_text(10'd86 + (char_idx << 5), 10'd350, (selected_map_id == 3'd3 ? 4'hF : 4'hB), (selected_map_id == 3'd3 ? 4'hD : 4'hB), (selected_map_id == 3'd3 ? 4'h4 : 4'hB), map_name_char(3'd3, char_idx));
                for (char_idx = 0; char_idx < 4; char_idx = char_idx + 1)
                    draw_text(10'd296 + (char_idx << 5), 10'd350, (selected_map_id == 3'd4 ? 4'hF : 4'hB), (selected_map_id == 3'd4 ? 4'hD : 4'hB), (selected_map_id == 3'd4 ? 4'h4 : 4'hB), map_name_char(3'd4, char_idx));
                for (char_idx = 0; char_idx < 4; char_idx = char_idx + 1)
                    draw_text(10'd506 + (char_idx << 5), 10'd350, (selected_map_id == 3'd5 ? 4'hF : 4'hB), (selected_map_id == 3'd5 ? 4'hD : 4'hB), (selected_map_id == 3'd5 ? 4'h4 : 4'hB), map_name_char(3'd5, char_idx));

                if (blink_on)
                    for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                        draw_text(10'd160 + (char_idx << 5), 10'd424, 4'hF, 4'hF, 4'hF, prompt_char(char_idx));
            end else if (game_over) begin
                rgb_r = 4'h2;
                rgb_g = 4'h0;
                rgb_b = 4'h0;
                if ((pixel_x >= 10'd72) && (pixel_x <= 10'd567) &&
                    (pixel_y >= 10'd72) && (pixel_y <= 10'd407)) begin
                    rgb_r = 4'h4;
                    rgb_g = 4'h0;
                    rgb_b = 4'h0;
                end
                if ((pixel_x == 10'd72) || (pixel_x == 10'd567) ||
                    (pixel_y == 10'd72) || (pixel_y == 10'd407)) begin
                    rgb_r = 4'hF;
                    rgb_g = 4'h5;
                    rgb_b = 4'h2;
                end
                for (char_idx = 0; char_idx < 9; char_idx = char_idx + 1)
                    draw_text(10'd176 + (char_idx << 5), 10'd112, 4'hF, 4'hE, 4'hD, result_char(2'd0, char_idx, game_result));
                for (char_idx = 0; char_idx < 6; char_idx = char_idx + 1)
                    draw_text(10'd224 + (char_idx << 5), 10'd224, 4'hF, 4'hD, 4'h4, result_char(2'd1, char_idx, game_result));
                if (blink_on)
                    for (char_idx = 0; char_idx < 10; char_idx = char_idx + 1)
                        draw_text(10'd160 + (char_idx << 5), 10'd304, 4'hF, 4'hF, 4'hF, result_char(2'd2, char_idx, game_result));
            end
        end
    end

endmodule

module buzzer_pattern (
    input  wire clk,
    input  wire reset,
    input  wire fire_event,
    input  wire hit_event,
    input  wire game_over_event,
    output reg  buzzer_n
);

    localparam [1:0] PATTERN_NONE = 2'd0;
    localparam [1:0] PATTERN_FIRE = 2'd1;
    localparam [1:0] PATTERN_HIT  = 2'd2;
    localparam [1:0] PATTERN_OVER = 2'd3;

    reg [16:0] ms_counter;
    reg [1:0]  pattern_id;
    reg [2:0]  phase;
    reg [8:0]  phase_timer;
    reg        active;
    wire       ms_tick;

    assign ms_tick = (ms_counter == 17'd99_999);

    always @(posedge clk) begin
        if (reset) begin
            ms_counter <= 17'd0;
        end else if (ms_tick) begin
            ms_counter <= 17'd0;
        end else begin
            ms_counter <= ms_counter + 17'd1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            pattern_id <= PATTERN_NONE;
            phase <= 3'd0;
            phase_timer <= 9'd0;
            active <= 1'b0;
            buzzer_n <= 1'b1;
        end else if (game_over_event) begin
            pattern_id <= PATTERN_OVER;
            phase <= 3'd0;
            phase_timer <= 9'd79;
            active <= 1'b1;
            buzzer_n <= 1'b0;
        end else if (hit_event) begin
            pattern_id <= PATTERN_HIT;
            phase <= 3'd0;
            phase_timer <= 9'd179;
            active <= 1'b1;
            buzzer_n <= 1'b0;
        end else if (fire_event && !active) begin
            pattern_id <= PATTERN_FIRE;
            phase <= 3'd0;
            phase_timer <= 9'd49;
            active <= 1'b1;
            buzzer_n <= 1'b0;
        end else if (ms_tick && active) begin
            if (phase_timer != 9'd0) begin
                phase_timer <= phase_timer - 9'd1;
            end else begin
                case (pattern_id)
                    PATTERN_FIRE: begin
                        active <= 1'b0;
                        pattern_id <= PATTERN_NONE;
                        buzzer_n <= 1'b1;
                    end
                    PATTERN_HIT: begin
                        active <= 1'b0;
                        pattern_id <= PATTERN_NONE;
                        buzzer_n <= 1'b1;
                    end
                    PATTERN_OVER: begin
                        case (phase)
                            3'd0: begin
                                phase <= 3'd1;
                                phase_timer <= 9'd59;
                                buzzer_n <= 1'b1;
                            end
                            3'd1: begin
                                phase <= 3'd2;
                                phase_timer <= 9'd79;
                                buzzer_n <= 1'b0;
                            end
                            3'd2: begin
                                phase <= 3'd3;
                                phase_timer <= 9'd59;
                                buzzer_n <= 1'b1;
                            end
                            3'd3: begin
                                phase <= 3'd4;
                                phase_timer <= 9'd139;
                                buzzer_n <= 1'b0;
                            end
                            default: begin
                                active <= 1'b0;
                                pattern_id <= PATTERN_NONE;
                                buzzer_n <= 1'b1;
                            end
                        endcase
                    end
                    default: begin
                        active <= 1'b0;
                        buzzer_n <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule

module seg7_digit_decoder (
    input  wire [3:0] digit,
    output reg  [6:0] segments_low
);

    always @(*) begin
        case (digit)
            4'd0: segments_low = 7'b0000001;
            4'd1: segments_low = 7'b1001111;
            4'd2: segments_low = 7'b0010010;
            4'd3: segments_low = 7'b0000110;
            default: segments_low = 7'b1111111;
        endcase
    end

endmodule

module keyboard_dual_mapper (
    input  wire       clk,
    input  wire       reset,
    input  wire       byte_ready,
    input  wire [7:0] byte_data,
    output reg        p1_up,
    output reg        p1_left,
    output reg        p1_down,
    output reg        p1_right,
    output reg        p1_fire,
    output reg        p2_up,
    output reg        p2_left,
    output reg        p2_down,
    output reg        p2_right,
    output reg        p2_fire
);

    reg break_pending;
    reg extend_pending;
    reg [18:0] prefix_timeout_q;

    localparam [7:0] SCAN_F0    = 8'hF0;
    localparam [7:0] SCAN_E0    = 8'hE0;
    localparam [7:0] SCAN_W      = 8'h1D;
    localparam [7:0] SCAN_A      = 8'h1C;
    localparam [7:0] SCAN_S      = 8'h1B;
    localparam [7:0] SCAN_D      = 8'h23;
    localparam [7:0] SCAN_SPACE  = 8'h29;
    localparam [7:0] SCAN_ENTER  = 8'h5A;
    localparam [7:0] SCAN_UP     = 8'h75;
    localparam [7:0] SCAN_DOWN   = 8'h72;
    localparam [7:0] SCAN_LEFT   = 8'h6B;
    localparam [7:0] SCAN_RIGHT  = 8'h74;
    localparam [18:0] PREFIX_TIMEOUT_CYCLES = 19'd500000;

    always @(posedge clk) begin
        if (reset) begin
            p1_up <= 1'b0;
            p1_left <= 1'b0;
            p1_down <= 1'b0;
            p1_right <= 1'b0;
            p1_fire <= 1'b0;
            p2_up <= 1'b0;
            p2_left <= 1'b0;
            p2_down <= 1'b0;
            p2_right <= 1'b0;
            p2_fire <= 1'b0;
            break_pending <= 1'b0;
            extend_pending <= 1'b0;
            prefix_timeout_q <= 19'd0;
        end else if (byte_ready) begin
            prefix_timeout_q <= 19'd0;
            if (byte_data == SCAN_F0) begin
                break_pending <= 1'b1;
            end else if (byte_data == SCAN_E0) begin
                extend_pending <= 1'b1;
            end else begin
                if (extend_pending) begin
                    case (byte_data)
                        SCAN_UP:    p2_up    <= ~break_pending;
                        SCAN_LEFT:  p2_left  <= ~break_pending;
                        SCAN_DOWN:  p2_down  <= ~break_pending;
                        SCAN_RIGHT: p2_right <= ~break_pending;
                        SCAN_ENTER: p2_fire  <= ~break_pending;
                        default: begin end
                    endcase
                end else begin
                    case (byte_data)
                        SCAN_W:     p1_up    <= ~break_pending;
                        SCAN_A:     p1_left  <= ~break_pending;
                        SCAN_S:     p1_down  <= ~break_pending;
                        SCAN_D:     p1_right <= ~break_pending;
                        SCAN_SPACE: p1_fire  <= ~break_pending;
                        SCAN_UP:    p2_up    <= ~break_pending;
                        SCAN_LEFT:  p2_left  <= ~break_pending;
                        SCAN_DOWN:  p2_down  <= ~break_pending;
                        SCAN_RIGHT: p2_right <= ~break_pending;
                        SCAN_ENTER: p2_fire  <= ~break_pending;
                        default: begin end
                    endcase
                end

                break_pending <= 1'b0;
                extend_pending <= 1'b0;
            end
        end else if (break_pending || extend_pending) begin
            if (prefix_timeout_q == PREFIX_TIMEOUT_CYCLES) begin
                break_pending <= 1'b0;
                extend_pending <= 1'b0;
                prefix_timeout_q <= 19'd0;
            end else begin
                prefix_timeout_q <= prefix_timeout_q + 19'd1;
            end
        end else begin
            prefix_timeout_q <= 19'd0;
        end
    end

endmodule

module move_tick_gen (
    input  wire clk,
    input  wire reset,
    output reg  tick_20hz
);

`ifdef SIM_FAST_VGA
    localparam integer MOVE_DIV = 1_250_000;
`else
    localparam integer MOVE_DIV = 5_000_000;
`endif
    reg [22:0] counter;

    always @(posedge clk) begin
        if (reset) begin
            counter   <= 23'd0;
            tick_20hz <= 1'b0;
        end else if (counter == MOVE_DIV - 1) begin
            counter   <= 23'd0;
            tick_20hz <= 1'b1;
        end else begin
            counter   <= counter + 23'd1;
            tick_20hz <= 1'b0;
        end
    end

endmodule

module bullet_tick_gen (
    input  wire clk,
    input  wire reset,
    output reg  tick_40hz
);

`ifdef SIM_FAST_VGA
    localparam integer BULLET_DIV = 625_000;
`else
    localparam integer BULLET_DIV = 2_500_000;
`endif
    reg [21:0] counter;

    always @(posedge clk) begin
        if (reset) begin
            counter   <= 22'd0;
            tick_40hz <= 1'b0;
        end else if (counter == BULLET_DIV - 1) begin
            counter   <= 22'd0;
            tick_40hz <= 1'b1;
        end else begin
            counter   <= counter + 22'd1;
            tick_40hz <= 1'b0;
        end
    end

endmodule

module collision_check (
    input  wire [10:0] obj_x,
    input  wire [9:0]  obj_y,
    input  wire [10:0] blocker_x,
    input  wire [9:0]  blocker_y,
    input  wire [2:0]  map_id,
    output wire        move_ok
);

    wire in_bounds;
    wire hit_blocker;
    wire hit_wall;

    wire [5:0] left_tile;
    wire [5:0] right_tile;
    wire [4:0] top_tile;
    wire [4:0] bottom_tile;
    wire [1:0] tl_type;
    wire [1:0] tr_type;
    wire [1:0] bl_type;
    wire [1:0] br_type;

    assign in_bounds = (obj_x >= 11'd16) && (obj_x <= 11'd608) &&
                       (obj_y >= 10'd16) && (obj_y <= 10'd448);

    assign hit_blocker = (obj_x < blocker_x + 11'd16) && (obj_x + 11'd16 > blocker_x) &&
                         (obj_y < blocker_y + 10'd16) && (obj_y + 10'd16 > blocker_y);

    assign left_tile   = obj_x[10:4];
    assign right_tile  = (obj_x + 11'd15) >> 4;
    assign top_tile    = obj_y[9:4];
    assign bottom_tile = (obj_y + 10'd15) >> 4;

    map_rom corner_tl (.map_id(map_id), .tile_x(left_tile),  .tile_y(top_tile),    .tile_type(tl_type));
    map_rom corner_tr (.map_id(map_id), .tile_x(right_tile), .tile_y(top_tile),    .tile_type(tr_type));
    map_rom corner_bl (.map_id(map_id), .tile_x(left_tile),  .tile_y(bottom_tile), .tile_type(bl_type));
    map_rom corner_br (.map_id(map_id), .tile_x(right_tile), .tile_y(bottom_tile), .tile_type(br_type));

    assign hit_wall = (tl_type != 2'b00) || (tr_type != 2'b00) ||
                      (bl_type != 2'b00) || (br_type != 2'b00);

    assign move_ok = in_bounds && !hit_blocker && !hit_wall;

endmodule

module bullet_collision_check (
    input  wire [10:0] obj_x,
    input  wire [9:0]  obj_y,
    input  wire [2:0]  map_id,
    output wire        move_ok
);

    wire in_bounds;
    wire hit_wall;

    wire [5:0] left_tile;
    wire [5:0] right_tile;
    wire [4:0] top_tile;
    wire [4:0] bottom_tile;
    wire [1:0] tl_type;
    wire [1:0] tr_type;
    wire [1:0] bl_type;
    wire [1:0] br_type;

    assign in_bounds = (obj_x >= 11'd16) && (obj_x <= 11'd618) &&
                       (obj_y >= 10'd16) && (obj_y <= 10'd458);

    assign left_tile   = obj_x[10:4];
    assign right_tile  = (obj_x + 11'd5) >> 4;
    assign top_tile    = obj_y[9:4];
    assign bottom_tile = (obj_y + 10'd5) >> 4;

    map_rom bullet_tl (.map_id(map_id), .tile_x(left_tile),  .tile_y(top_tile),    .tile_type(tl_type));
    map_rom bullet_tr (.map_id(map_id), .tile_x(right_tile), .tile_y(top_tile),    .tile_type(tr_type));
    map_rom bullet_bl (.map_id(map_id), .tile_x(left_tile),  .tile_y(bottom_tile), .tile_type(bl_type));
    map_rom bullet_br (.map_id(map_id), .tile_x(right_tile), .tile_y(bottom_tile), .tile_type(br_type));

    assign hit_wall = (tl_type != 2'b00) || (tr_type != 2'b00) ||
                      (bl_type != 2'b00) || (br_type != 2'b00);

    assign move_ok = in_bounds && !hit_wall;

endmodule

module tank_sprite (
    input  wire [3:0] local_x,
    input  wire [3:0] local_y,
    input  wire [1:0] dir,
    output reg        pixel_on
);

    localparam [1:0] DIR_UP    = 2'd0;
    localparam [1:0] DIR_RIGHT = 2'd1;
    localparam [1:0] DIR_DOWN  = 2'd2;
    localparam [1:0] DIR_LEFT  = 2'd3;

    wire track_left;
    wire track_right;
    wire track_top;
    wire track_bottom;
    wire body_core;
    wire turret_center;

    assign track_left    = (local_x >= 4'd1)  && (local_x <= 4'd3);
    assign track_right   = (local_x >= 4'd12) && (local_x <= 4'd14);
    assign track_top     = (local_y >= 4'd1)  && (local_y <= 4'd3);
    assign track_bottom  = (local_y >= 4'd12) && (local_y <= 4'd14);
    assign body_core     = (local_x >= 4'd4)  && (local_x <= 4'd11) &&
                           (local_y >= 4'd4)  && (local_y <= 4'd11);
    assign turret_center = (local_x >= 4'd6)  && (local_x <= 4'd9)  &&
                           (local_y >= 4'd6)  && (local_y <= 4'd9);

    always @(*) begin
        pixel_on = 1'b0;

        case (dir)
            DIR_UP: begin
                if (((track_left || track_right) && (local_y >= 4'd2) && (local_y <= 4'd13)) ||
                    body_core ||
                    ((local_x >= 4'd6) && (local_x <= 4'd9) && (local_y >= 4'd0) && (local_y <= 4'd5)) ||
                    turret_center)
                    pixel_on = 1'b1;
            end

            DIR_RIGHT: begin
                if (((track_top || track_bottom) && (local_x >= 4'd2) && (local_x <= 4'd13)) ||
                    body_core ||
                    ((local_y >= 4'd6) && (local_y <= 4'd9) && (local_x >= 4'd10) && (local_x <= 4'd15)) ||
                    turret_center)
                    pixel_on = 1'b1;
            end

            DIR_DOWN: begin
                if (((track_left || track_right) && (local_y >= 4'd2) && (local_y <= 4'd13)) ||
                    body_core ||
                    ((local_x >= 4'd6) && (local_x <= 4'd9) && (local_y >= 4'd10) && (local_y <= 4'd15)) ||
                    turret_center)
                    pixel_on = 1'b1;
            end

            DIR_LEFT: begin
                if (((track_top || track_bottom) && (local_x >= 4'd2) && (local_x <= 4'd13)) ||
                    body_core ||
                    ((local_y >= 4'd6) && (local_y <= 4'd9) && (local_x >= 4'd0) && (local_x <= 4'd5)) ||
                    turret_center)
                    pixel_on = 1'b1;
            end

            default: begin
                pixel_on = 1'b0;
            end
        endcase
    end

endmodule

module map_rom (
    input  wire [2:0] map_id,
    input  wire [5:0] tile_x,
    input  wire [4:0] tile_y,
    output reg  [1:0] tile_type
);

    localparam [1:0] TILE_GRASS = 2'b00;
    localparam [1:0] TILE_STEEL = 2'b01;
    localparam [1:0] TILE_BRICK = 2'b10;
    localparam [2:0] MAP_CLASSIC  = 3'd0;
    localparam [2:0] MAP_LANES    = 3'd1;
    localparam [2:0] MAP_FORTRESS = 3'd2;
    localparam [2:0] MAP_MAZE     = 3'd3;
    localparam [2:0] MAP_OPEN     = 3'd4;
    localparam [2:0] MAP_QUAD     = 3'd5;

    always @(*) begin
        tile_type = TILE_GRASS;

        if ((tile_x == 6'd0) || (tile_x == 6'd39) || (tile_y == 5'd0) || (tile_y == 5'd29)) begin
            tile_type = TILE_STEEL;
        end else begin
            case (map_id)
                MAP_CLASSIC: begin
                    if (((tile_x >= 6'd5)  && (tile_x <= 6'd10) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd34) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd10) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd34) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd16) && (tile_y >= 5'd8)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd27) && (tile_y >= 5'd8)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd16) && (tile_y >= 5'd20) && (tile_y <= 5'd21)) ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd27) && (tile_y >= 5'd20) && (tile_y <= 5'd21)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd5)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd23) && (tile_y <= 5'd24)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd12) && (tile_y <= 5'd13)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd14) && (tile_x <= 6'd15) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd24) && (tile_x <= 6'd25) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd7)  && (tile_x <= 6'd10) && (tile_y >= 5'd12) && (tile_y <= 5'd13)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd32) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd7)  && (tile_x <= 6'd10) && (tile_y >= 5'd17) && (tile_y <= 5'd18)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd32) && (tile_y >= 5'd11) && (tile_y <= 5'd12)))
                        tile_type = TILE_BRICK;
                end
                MAP_LANES: begin
                    if (((tile_x >= 6'd3)  && (tile_x <= 6'd9)  && (tile_y >= 5'd9)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd13) && (tile_x <= 6'd18) && (tile_y >= 5'd9)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd22) && (tile_x <= 6'd27) && (tile_y >= 5'd9)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd31) && (tile_x <= 6'd37) && (tile_y >= 5'd9)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd3)  && (tile_x <= 6'd7)  && (tile_y >= 5'd19) && (tile_y <= 5'd20)) ||
                        ((tile_x >= 6'd11) && (tile_x <= 6'd16) && (tile_y >= 5'd19) && (tile_y <= 5'd20)) ||
                        ((tile_x >= 6'd20) && (tile_x <= 6'd25) && (tile_y >= 5'd19) && (tile_y <= 5'd20)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd37) && (tile_y >= 5'd19) && (tile_y <= 5'd20)) ||
                        ((tile_x >= 6'd10) && (tile_x <= 6'd12) && (tile_y >= 5'd4)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd27) && (tile_x <= 6'd29) && (tile_y >= 5'd4)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd10) && (tile_x <= 6'd12) && (tile_y >= 5'd23) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd27) && (tile_x <= 6'd29) && (tile_y >= 5'd23) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd19) && (tile_x <= 6'd20) && (tile_y >= 5'd13) && (tile_y <= 5'd16)) ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd8)  && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd31) && (tile_x <= 6'd34) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd16) && (tile_x <= 6'd23) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd16) && (tile_x <= 6'd23) && (tile_y >= 5'd24) && (tile_y <= 5'd25)))
                        tile_type = TILE_BRICK;
                end
                MAP_FORTRESS: begin
                    if (((tile_x >= 6'd15) && (tile_x <= 6'd18) && (tile_y >= 5'd10) && (tile_y <= 5'd11)) ||
                        ((tile_x >= 6'd21) && (tile_x <= 6'd24) && (tile_y >= 5'd10) && (tile_y <= 5'd11)) ||
                        ((tile_x >= 6'd15) && (tile_x <= 6'd18) && (tile_y >= 5'd18) && (tile_y <= 5'd19)) ||
                        ((tile_x >= 6'd21) && (tile_x <= 6'd24) && (tile_y >= 5'd18) && (tile_y <= 5'd19)) ||
                        ((tile_x >= 6'd15) && (tile_x <= 6'd16) && (tile_y >= 5'd12) && (tile_y <= 5'd14)) ||
                        ((tile_x >= 6'd15) && (tile_x <= 6'd16) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd24) && (tile_y >= 5'd12) && (tile_y <= 5'd14)) ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd24) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd4)  && (tile_x <= 6'd9)  && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd30) && (tile_x <= 6'd35) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd10) && (tile_y >= 5'd8)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd34) && (tile_y >= 5'd20) && (tile_y <= 5'd21)) ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd8)  && (tile_y >= 5'd20) && (tile_y <= 5'd22)) ||
                        ((tile_x >= 6'd31) && (tile_x <= 6'd34) && (tile_y >= 5'd7)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd13) && (tile_y >= 5'd4)  && (tile_y <= 5'd8))  ||
                        ((tile_x >= 6'd26) && (tile_x <= 6'd27) && (tile_y >= 5'd21) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd16) && (tile_y >= 5'd22) && (tile_y <= 5'd23)) ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd27) && (tile_y >= 5'd6)  && (tile_y <= 5'd7))  ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd20) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd19) && (tile_x <= 6'd21) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd8)  && (tile_x <= 6'd12) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd27) && (tile_x <= 6'd31) && (tile_y >= 5'd14) && (tile_y <= 5'd15)))
                        tile_type = TILE_BRICK;
                end
                MAP_MAZE: begin
                    if (((tile_x >= 6'd5)  && (tile_x <= 6'd6)  && (tile_y >= 5'd2)  && (tile_y <= 5'd8))  ||
                        ((tile_x >= 6'd10) && (tile_x <= 6'd16) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd20) && (tile_x <= 6'd21) && (tile_y >= 5'd2)  && (tile_y <= 5'd7))  ||
                        ((tile_x >= 6'd25) && (tile_x <= 6'd34) && (tile_y >= 5'd5)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd3)  && (tile_x <= 6'd11) && (tile_y >= 5'd12) && (tile_y <= 5'd13)) ||
                        ((tile_x >= 6'd15) && (tile_x <= 6'd16) && (tile_y >= 5'd9)  && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd20) && (tile_x <= 6'd28) && (tile_y >= 5'd12) && (tile_y <= 5'd13)) ||
                        ((tile_x >= 6'd32) && (tile_x <= 6'd33) && (tile_y >= 5'd9)  && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd6)  && (tile_y >= 5'd20) && (tile_y <= 5'd27)) ||
                        ((tile_x >= 6'd10) && (tile_x <= 6'd18) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd22) && (tile_x <= 6'd23) && (tile_y >= 5'd21) && (tile_y <= 5'd27)) ||
                        ((tile_x >= 6'd27) && (tile_x <= 6'd36) && (tile_y >= 5'd23) && (tile_y <= 5'd24)) ||
                        ((tile_x >= 6'd8)  && (tile_x <= 6'd12) && (tile_y >= 5'd8)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd24) && (tile_x <= 6'd30) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd19) && (tile_y >= 5'd18) && (tile_y <= 5'd19)) ||
                        ((tile_x >= 6'd21) && (tile_x <= 6'd28) && (tile_y >= 5'd8)  && (tile_y <= 5'd9))  ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd20) && (tile_y >= 5'd22) && (tile_y <= 5'd23)) ||
                        ((tile_x == 6'd19) && (tile_y >= 5'd6)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd7)  && (tile_x <= 6'd10) && (tile_y >= 5'd15) && (tile_y <= 5'd16)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd32) && (tile_y >= 5'd19) && (tile_y <= 5'd20)) ||
                        ((tile_x >= 6'd13) && (tile_x <= 6'd14) && (tile_y >= 5'd2)  && (tile_y <= 5'd3))  ||
                        ((tile_x >= 6'd35) && (tile_x <= 6'd36) && (tile_y >= 5'd12) && (tile_y <= 5'd14)))
                        tile_type = TILE_BRICK;
                end
                MAP_OPEN: begin
                    if (((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd13) && (tile_y <= 5'd16)) ||
                        ((tile_x >= 6'd8)  && (tile_x <= 6'd10) && (tile_y >= 5'd6)  && (tile_y <= 5'd7))  ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd31) && (tile_y >= 5'd22) && (tile_y <= 5'd23)) ||
                        ((tile_x >= 6'd8)  && (tile_x <= 6'd10) && (tile_y >= 5'd22) && (tile_y <= 5'd23)) ||
                        ((tile_x >= 6'd29) && (tile_x <= 6'd31) && (tile_y >= 5'd6)  && (tile_y <= 5'd7))  ||
                        ((tile_x >= 6'd14) && (tile_x <= 6'd16) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd25) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd14) && (tile_x <= 6'd16) && (tile_y >= 5'd24) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd23) && (tile_x <= 6'd25) && (tile_y >= 5'd4)  && (tile_y <= 5'd5))  ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd7)  && (tile_y >= 5'd11) && (tile_y <= 5'd12)) ||
                        ((tile_x >= 6'd32) && (tile_x <= 6'd34) && (tile_y >= 5'd17) && (tile_y <= 5'd18)) ||
                        ((tile_x >= 6'd5)  && (tile_x <= 6'd7)  && (tile_y >= 5'd17) && (tile_y <= 5'd18)) ||
                        ((tile_x >= 6'd32) && (tile_x <= 6'd34) && (tile_y >= 5'd11) && (tile_y <= 5'd12)) ||
                        ((tile_x >= 6'd12) && (tile_x <= 6'd14) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd25) && (tile_x <= 6'd27) && (tile_y >= 5'd14) && (tile_y <= 5'd15)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd7)  && (tile_y <= 5'd8))  ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd21) && (tile_y <= 5'd22)) ||
                        ((tile_x >= 6'd2)  && (tile_x <= 6'd3)  && (tile_y >= 5'd4)  && (tile_y <= 5'd7))  ||
                        ((tile_x >= 6'd36) && (tile_x <= 6'd37) && (tile_y >= 5'd22) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd2)  && (tile_x <= 6'd3)  && (tile_y >= 5'd22) && (tile_y <= 5'd25)) ||
                        ((tile_x >= 6'd36) && (tile_x <= 6'd37) && (tile_y >= 5'd4)  && (tile_y <= 5'd7)))
                        tile_type = TILE_BRICK;
                end
                default: begin
                    if (((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd3)  && (tile_y <= 5'd8))  ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd21) && (tile_y <= 5'd26)) ||
                        ((tile_x >= 6'd3)  && (tile_x <= 6'd13) && (tile_y >= 5'd13) && (tile_y <= 5'd16)) ||
                        ((tile_x >= 6'd26) && (tile_x <= 6'd36) && (tile_y >= 5'd13) && (tile_y <= 5'd16)) ||
                        ((tile_x >= 6'd16) && (tile_x <= 6'd17) && (tile_y >= 5'd11) && (tile_y <= 5'd18)) ||
                        ((tile_x >= 6'd22) && (tile_x <= 6'd23) && (tile_y >= 5'd11) && (tile_y <= 5'd18)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd12) && (tile_y <= 5'd13)) ||
                        ((tile_x >= 6'd18) && (tile_x <= 6'd21) && (tile_y >= 5'd16) && (tile_y <= 5'd17)) ||
                        ((tile_x >= 6'd4)  && (tile_x <= 6'd9)  && (tile_y >= 5'd5)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd30) && (tile_x <= 6'd35) && (tile_y >= 5'd23) && (tile_y <= 5'd24)) ||
                        ((tile_x >= 6'd4)  && (tile_x <= 6'd9)  && (tile_y >= 5'd23) && (tile_y <= 5'd24)) ||
                        ((tile_x >= 6'd30) && (tile_x <= 6'd35) && (tile_y >= 5'd5)  && (tile_y <= 5'd6))  ||
                        ((tile_x >= 6'd11) && (tile_x <= 6'd13) && (tile_y >= 5'd8)  && (tile_y <= 5'd11)) ||
                        ((tile_x >= 6'd26) && (tile_x <= 6'd28) && (tile_y >= 5'd18) && (tile_y <= 5'd21)) ||
                        ((tile_x >= 6'd11) && (tile_x <= 6'd13) && (tile_y >= 5'd19) && (tile_y <= 5'd22)) ||
                        ((tile_x >= 6'd26) && (tile_x <= 6'd28) && (tile_y >= 5'd7)  && (tile_y <= 5'd10)) ||
                        ((tile_x >= 6'd6)  && (tile_x <= 6'd8)  && (tile_y >= 5'd10) && (tile_y <= 5'd11)) ||
                        ((tile_x >= 6'd31) && (tile_x <= 6'd33) && (tile_y >= 5'd18) && (tile_y <= 5'd19)) ||
                        ((tile_x >= 6'd6)  && (tile_x <= 6'd8)  && (tile_y >= 5'd18) && (tile_y <= 5'd19)) ||
                        ((tile_x >= 6'd31) && (tile_x <= 6'd33) && (tile_y >= 5'd10) && (tile_y <= 5'd11)))
                        tile_type = TILE_BRICK;
                end
            endcase
        end
    end

endmodule

module tile_renderer (
    input  wire       display_active,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire [1:0] tile_type,
    output reg  [3:0] rgb_r,
    output reg  [3:0] rgb_g,
    output reg  [3:0] rgb_b
);

    localparam [1:0] TILE_GRASS = 2'b00;
    localparam [1:0] TILE_STEEL = 2'b01;
    localparam [1:0] TILE_BRICK = 2'b10;

    wire [3:0] local_x;
    wire [3:0] local_y;
    wire       brick_mortar;
    wire       steel_edge;

    assign local_x = pixel_x[3:0];
    assign local_y = pixel_y[3:0];
    assign brick_mortar = (local_y == 4'd0) || (local_y == 4'd8) ||
                          (local_x == 4'd0) || ((local_y < 4'd8) && (local_x == 4'd8));
    assign steel_edge = (local_x == 4'd0) || (local_x == 4'd15) ||
                        (local_y == 4'd0) || (local_y == 4'd15);

    always @(*) begin
        if (!display_active) begin
            rgb_r = 4'h0;
            rgb_g = 4'h0;
            rgb_b = 4'h0;
        end else begin
            case (tile_type)
                TILE_STEEL: begin
                    if (steel_edge) begin
                        rgb_r = 4'hC;
                        rgb_g = 4'hD;
                        rgb_b = 4'hF;
                    end else begin
                        rgb_r = 4'h7;
                        rgb_g = 4'h8;
                        rgb_b = 4'hA;
                    end
                end
                TILE_BRICK: begin
                    if (brick_mortar) begin
                        rgb_r = 4'h3;
                        rgb_g = 4'h1;
                        rgb_b = 4'h1;
                    end else begin
                        rgb_r = 4'hC;
                        rgb_g = 4'h5;
                        rgb_b = 4'h2;
                    end
                end
                default: begin
                    if ((local_x == 4'd0) || (local_y == 4'd0)) begin
                        rgb_r = 4'h0;
                        rgb_g = 4'h2;
                        rgb_b = 4'h0;
                    end else begin
                        rgb_r = 4'h1;
                        rgb_g = 4'h4;
                        rgb_b = 4'h1;
                    end
                end
            endcase
        end
    end

endmodule
