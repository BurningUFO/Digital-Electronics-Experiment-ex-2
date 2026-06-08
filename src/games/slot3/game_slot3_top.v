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

    localparam [2:0] ST_START = 3'd0;
    localparam [2:0] ST_PLAY  = 3'd1;
    localparam [2:0] ST_LOAD  = 3'd2;
    localparam [2:0] ST_WIN   = 3'd3;
    localparam [2:0] ST_LOSE  = 3'd4;

    assign led = 16'h0000;
    assign an = 8'hFF;
    assign {ca, cb, cc, cd, ce, cf, cg, dp} = 8'hFF;
    assign buzzer = 1'b1;

    reg [2:0]  state;
    reg [1:0]  menu_choice;
    reg [3:0]  start_difficulty;
    reg [3:0]  level;
    reg [31:0] lfsr;
    reg [15:0] frame_count;
    reg [7:0]  move_phase;
    reg        frame_tick_q;
    reg        start_level_req;
    reg        start_level_d;

    wire slot_reset_req = reset || !selected;
    (* max_fanout = 32 *) reg slot_reset_input;
    (* max_fanout = 32 *) reg slot_reset_player;
    (* max_fanout = 32 *) reg slot_reset_map;
    (* max_fanout = 32 *) reg slot_reset_entities;
    (* max_fanout = 32 *) reg slot_reset_quest;
    (* max_fanout = 32 *) reg slot_reset_combat;
    (* max_fanout = 32 *) reg slot_reset_video;
    (* max_fanout = 32 *) reg slot_reset_ctrl;

    wire start_level_pulse = start_level_req & ~start_level_d;
    wire playing = (state == ST_PLAY);

    initial begin
        slot_reset_input = 1'b1;
        slot_reset_player = 1'b1;
        slot_reset_map = 1'b1;
        slot_reset_entities = 1'b1;
        slot_reset_quest = 1'b1;
        slot_reset_combat = 1'b1;
        slot_reset_video = 1'b1;
        slot_reset_ctrl = 1'b1;
    end

    always @(posedge clk) begin
        slot_reset_input <= slot_reset_req;
        slot_reset_player <= slot_reset_req;
        slot_reset_map <= slot_reset_req;
        slot_reset_entities <= slot_reset_req;
        slot_reset_quest <= slot_reset_req;
        slot_reset_combat <= slot_reset_req;
        slot_reset_video <= slot_reset_req;
        slot_reset_ctrl <= slot_reset_req;
    end

    always @(posedge clk) begin
        if (slot_reset_ctrl) frame_tick_q <= 1'b0;
        else frame_tick_q <= frame_tick;
    end

    wire input_up, input_down, input_left, input_right;
    wire confirm_pulse, shoot_pulse, bomb_pulse, emp_pulse, cloak_pulse, esc_pulse, space_pulse;
    slot3_input u_input (
        .clk(clk), .reset(slot_reset_input), .selected(selected),
        .ps2_byte_ready(ps2_byte_ready),
        .ps2_byte_data(ps2_byte_data),
        .btn_u(btn_u), .btn_d(btn_d), .btn_l(btn_l), .btn_r(btn_r), .btn_c(btn_c),
        .input_up(input_up), .input_down(input_down),
        .input_left(input_left), .input_right(input_right),
        .confirm_pulse(confirm_pulse), .shoot_pulse(shoot_pulse),
        .bomb_pulse(bomb_pulse), .emp_pulse(emp_pulse),
        .cloak_pulse(cloak_pulse), .esc_pulse(esc_pulse),
        .space_pulse(space_pulse)
    );

    wire [9:0] neo_x, try_x;
    wire [8:0] neo_y, try_y;
    wire [1:0] neo_dir;
    wire has_bullet_time;
    wire [8:0] bt_timer, bt_cooldown;
    wire [7:0] attract_timer;
    wire [5:0] ammo;
    wire [2:0] charges_w;
    wire [1:0] emp_count;
    wire [2:0] rescued;
    wire bullet_time_active = (bt_timer != 9'd0);
    wire quest_touch_trinity;
    wire neo_touch_terminal;
    wire neo_touch_phone;
    wire [7:0] neo_touch_pickup;
    wire phone_reachable;
    wire pickup_give_ammo;
    wire pickup_give_charge;
    wire pickup_give_emp;
    wire neo_touch_red;
    reg  do_rescue_pulse;
    wire combat_use_ammo;
    wire combat_use_charge;
    wire combat_use_emp;

    wire walk_full_0, walk_full_1;
    wire walk_full = walk_full_0 && walk_full_1;

    slot3_player u_player (
        .clk(clk), .reset(slot_reset_player), .frame_tick(frame_tick_q),
        .playing(playing), .move_phase(move_phase),
        .input_up(input_up), .input_down(input_down),
        .input_left(input_left), .input_right(input_right),
        .space_pulse(space_pulse),
        .bullet_time_active(bullet_time_active),
        .walkable(walk_full),
        .neo_x(neo_x), .neo_y(neo_y), .neo_dir(neo_dir),
        .try_x(try_x), .try_y(try_y),
        .has_bullet_time(has_bullet_time),
        .bt_timer(bt_timer), .bt_cooldown(bt_cooldown),
        .attract_timer(attract_timer),
        .ammo(ammo), .charges(charges_w), .emp_count(emp_count), .rescued(rescued),
        .consume_ammo(combat_use_ammo),
        .consume_charge(combat_use_charge),
        .consume_emp(combat_use_emp),
        .give_bullet_time(quest_touch_trinity),
        .give_ammo(pickup_give_ammo),
        .give_charge(pickup_give_charge),
        .give_emp(pickup_give_emp),
        .do_attract(neo_touch_red),
        .do_rescue(do_rescue_pulse),
        .start_level(start_level_pulse)
    );

    wire map_gen_done;
    wire map_destroy_en;
    wire [4:0] map_destroy_tx;
    wire [3:0] map_destroy_ty;
    wire [2:0] render_tile;
    wire [3:0] river_y;
    slot3_map u_map (
        .clk(clk), .reset(slot_reset_map),
        .gen_start(start_level_pulse), .seed(lfsr), .level(level),
        .gen_done(map_gen_done),
        .destroy_en(map_destroy_en), .destroy_tx(map_destroy_tx), .destroy_ty(map_destroy_ty),
        .query_x0(try_x), .query_y0(try_y),
        .query_x1(try_x + 10'd15), .query_y1(try_y + 9'd19),
        .query_x2(try_x), .query_y2(try_y),
        .query_x3(try_x + 10'd15), .query_y3(try_y + 9'd19),
        .walk0(walk_full_0), .walk1(walk_full_1),
        .walk2(), .walk3(),
        .render_tx(pixel_x[9:5]), .render_ty(pixel_y[8:5]),
        .render_tile(render_tile), .river_y(river_y)
    );

    wire [9:0] smith_x0, smith_x1, smith_x2, smith_x3, smith_x4, smith_x5, smith_x6, smith_x7;
    wire [8:0] smith_y0, smith_y1, smith_y2, smith_y3, smith_y4, smith_y5, smith_y6, smith_y7;
    wire [1:0] smith_type0, smith_type1, smith_type2, smith_type3, smith_type4, smith_type5, smith_type6, smith_type7;
    wire [7:0] smith_active;
    wire [5:0] smith_stun0, smith_stun1, smith_stun2, smith_stun3, smith_stun4, smith_stun5, smith_stun6, smith_stun7;
    wire [7:0] smith_chasing;
    wire [9:0] npc_x0, npc_x1, npc_x2, npc_x3, npc_x4, npc_x5, npc_x6, npc_x7;
    wire [8:0] npc_y0, npc_y1, npc_y2, npc_y3, npc_y4, npc_y5, npc_y6, npc_y7;
    wire [7:0] npc_alive;
    wire [9:0] red_x, trinity_x;
    wire [8:0] red_y, trinity_y;
    wire [7:0] combat_smith_kill;
    wire [7:0] combat_smith_stun;
    wire [7:0] npc_rescue_mask;
    wire       combat_replicate_en;
    wire [2:0] combat_replicate_idx;

    slot3_entities u_entities (
        .clk(clk), .reset(slot_reset_entities),
        .frame_tick(frame_tick_q), .playing(playing),
        .move_phase(move_phase), .lfsr(lfsr), .level(level),
        .bullet_time_active(bullet_time_active),
        .attract_timer(attract_timer),
        .neo_x(neo_x), .neo_y(neo_y), .neo_dir(neo_dir),
        .river_y(river_y),
        .start_level(start_level_pulse), .init_seed(lfsr),
        .smith_kill_mask(combat_smith_kill),
        .smith_stun_set(combat_smith_stun),
        .npc_rescue_mask(npc_rescue_mask),
        .replicate_en(combat_replicate_en),
        .replicate_npc_idx(combat_replicate_idx),
        .smith_x0(smith_x0), .smith_x1(smith_x1), .smith_x2(smith_x2), .smith_x3(smith_x3),
        .smith_x4(smith_x4), .smith_x5(smith_x5), .smith_x6(smith_x6), .smith_x7(smith_x7),
        .smith_y0(smith_y0), .smith_y1(smith_y1), .smith_y2(smith_y2), .smith_y3(smith_y3),
        .smith_y4(smith_y4), .smith_y5(smith_y5), .smith_y6(smith_y6), .smith_y7(smith_y7),
        .smith_type0(smith_type0), .smith_type1(smith_type1), .smith_type2(smith_type2), .smith_type3(smith_type3),
        .smith_type4(smith_type4), .smith_type5(smith_type5), .smith_type6(smith_type6), .smith_type7(smith_type7),
        .smith_active(smith_active),
        .smith_stun0(smith_stun0), .smith_stun1(smith_stun1), .smith_stun2(smith_stun2), .smith_stun3(smith_stun3),
        .smith_stun4(smith_stun4), .smith_stun5(smith_stun5), .smith_stun6(smith_stun6), .smith_stun7(smith_stun7),
        .smith_chasing(smith_chasing),
        .npc_x0(npc_x0), .npc_x1(npc_x1), .npc_x2(npc_x2), .npc_x3(npc_x3),
        .npc_x4(npc_x4), .npc_x5(npc_x5), .npc_x6(npc_x6), .npc_x7(npc_x7),
        .npc_y0(npc_y0), .npc_y1(npc_y1), .npc_y2(npc_y2), .npc_y3(npc_y3),
        .npc_y4(npc_y4), .npc_y5(npc_y5), .npc_y6(npc_y6), .npc_y7(npc_y7),
        .npc_alive(npc_alive),
        .red_x(red_x), .red_y(red_y),
        .trinity_x(trinity_x), .trinity_y(trinity_y)
    );

    wire [1:0] quest_phase;
    wire trinity_found, terminal_hacked;
    wire [2:0] rescue_goal;
    wire [9:0] phone_x, terminal_x;
    wire [8:0] phone_y, terminal_y;
    wire [9:0] pickup_x0, pickup_x1, pickup_x2, pickup_x3, pickup_x4, pickup_x5, pickup_x6, pickup_x7;
    wire [8:0] pickup_y0, pickup_y1, pickup_y2, pickup_y3, pickup_y4, pickup_y5, pickup_y6, pickup_y7;
    wire [2:0] pickup_type0, pickup_type1, pickup_type2, pickup_type3, pickup_type4, pickup_type5, pickup_type6, pickup_type7;
    wire [7:0] pickup_active;
    slot3_quest u_quest (
        .clk(clk), .reset(slot_reset_quest),
        .frame_tick(frame_tick_q), .playing(playing),
        .neo_x(neo_x), .neo_y(neo_y),
        .trinity_x(trinity_x), .trinity_y(trinity_y),
        .lfsr(lfsr), .start_level(start_level_pulse), .level(level),
        .rescued(rescued),
        .quest_phase(quest_phase), .trinity_found(trinity_found),
        .terminal_hacked(terminal_hacked), .rescue_goal(rescue_goal),
        .phone_x(phone_x), .phone_y(phone_y),
        .terminal_x(terminal_x), .terminal_y(terminal_y),
        .pickup_x0(pickup_x0), .pickup_x1(pickup_x1), .pickup_x2(pickup_x2), .pickup_x3(pickup_x3),
        .pickup_x4(pickup_x4), .pickup_x5(pickup_x5), .pickup_x6(pickup_x6), .pickup_x7(pickup_x7),
        .pickup_y0(pickup_y0), .pickup_y1(pickup_y1), .pickup_y2(pickup_y2), .pickup_y3(pickup_y3),
        .pickup_y4(pickup_y4), .pickup_y5(pickup_y5), .pickup_y6(pickup_y6), .pickup_y7(pickup_y7),
        .pickup_type0(pickup_type0), .pickup_type1(pickup_type1), .pickup_type2(pickup_type2), .pickup_type3(pickup_type3),
        .pickup_type4(pickup_type4), .pickup_type5(pickup_type5), .pickup_type6(pickup_type6), .pickup_type7(pickup_type7),
        .pickup_active(pickup_active),
        .neo_touch_trinity(quest_touch_trinity),
        .neo_touch_terminal(neo_touch_terminal),
        .neo_touch_phone(neo_touch_phone),
        .neo_touch_pickup(neo_touch_pickup),
        .phone_reachable(phone_reachable)
    );

    wire [7:0] is_ammo = {
        (pickup_type7 == 3'd1), (pickup_type6 == 3'd1),
        (pickup_type5 == 3'd1), (pickup_type4 == 3'd1),
        (pickup_type3 == 3'd1), (pickup_type2 == 3'd1),
        (pickup_type1 == 3'd1), (pickup_type0 == 3'd1)
    };
    wire [7:0] is_charge = {
        (pickup_type7 == 3'd2), (pickup_type6 == 3'd2),
        (pickup_type5 == 3'd2), (pickup_type4 == 3'd2),
        (pickup_type3 == 3'd2), (pickup_type2 == 3'd2),
        (pickup_type1 == 3'd2), (pickup_type0 == 3'd2)
    };
    wire [7:0] is_emp = {
        (pickup_type7 == 3'd3), (pickup_type6 == 3'd3),
        (pickup_type5 == 3'd3), (pickup_type4 == 3'd3),
        (pickup_type3 == 3'd3), (pickup_type2 == 3'd3),
        (pickup_type1 == 3'd3), (pickup_type0 == 3'd3)
    };

    assign pickup_give_ammo   = |(neo_touch_pickup & pickup_active & is_ammo);
    assign pickup_give_charge = |(neo_touch_pickup & pickup_active & is_charge);
    assign pickup_give_emp    = |(neo_touch_pickup & pickup_active & is_emp);
    assign neo_touch_red = playing &&
        (neo_x < red_x + 10'd16) && (neo_x + 10'd16 > red_x) &&
        (neo_y < red_y + 9'd20) && (neo_y + 9'd20 > red_y) &&
        (attract_timer == 8'd0);

    wire [9:0] nx [0:7];
    wire [8:0] ny [0:7];
    assign nx[0]=npc_x0; assign nx[1]=npc_x1; assign nx[2]=npc_x2; assign nx[3]=npc_x3;
    assign nx[4]=npc_x4; assign nx[5]=npc_x5; assign nx[6]=npc_x6; assign nx[7]=npc_x7;
    assign ny[0]=npc_y0; assign ny[1]=npc_y1; assign ny[2]=npc_y2; assign ny[3]=npc_y3;
    assign ny[4]=npc_y4; assign ny[5]=npc_y5; assign ny[6]=npc_y6; assign ny[7]=npc_y7;

    reg [7:0] npc_rescue_reg;
    integer ri;
    always @(*) begin
        npc_rescue_reg = 8'd0;
        do_rescue_pulse = 1'b0;
        if (playing && terminal_hacked) begin
            for (ri = 0; ri < 8; ri = ri + 1) begin
                if (npc_alive[ri] &&
                    (neo_x < nx[ri] + 10'd15) && (neo_x + 10'd16 > nx[ri]) &&
                    (neo_y < ny[ri] + 9'd19) && (neo_y + 9'd20 > ny[ri])) begin
                    npc_rescue_reg[ri] = 1'b1;
                    do_rescue_pulse = 1'b1;
                end
            end
        end
    end
    assign npc_rescue_mask = npc_rescue_reg;

    wire [9:0] bullet_x0, bullet_x1, bullet_x2, bullet_x3;
    wire [8:0] bullet_y0, bullet_y1, bullet_y2, bullet_y3;
    wire [1:0] bullet_dir0, bullet_dir1, bullet_dir2, bullet_dir3;
    wire [3:0] bullet_active;
    wire [9:0] bomb_x0, bomb_x1, bomb_x2, bomb_x3;
    wire [8:0] bomb_y0, bomb_y1, bomb_y2, bomb_y3;
    wire [7:0] bomb_timer0, bomb_timer1, bomb_timer2, bomb_timer3;
    wire [3:0] bomb_active;
    wire [8:0] emp_visual;
    slot3_combat u_combat (
        .clk(clk), .reset(slot_reset_combat),
        .frame_tick(frame_tick_q), .playing(playing), .move_phase(move_phase),
        .shoot_pulse(shoot_pulse), .bomb_pulse(bomb_pulse), .emp_pulse(emp_pulse),
        .neo_x(neo_x), .neo_y(neo_y), .neo_dir(neo_dir),
        .ammo(ammo), .charges(charges_w), .emp_count(emp_count),
        .bullet_time_active(bullet_time_active),
        .smith_x0(smith_x0), .smith_x1(smith_x1), .smith_x2(smith_x2), .smith_x3(smith_x3),
        .smith_x4(smith_x4), .smith_x5(smith_x5), .smith_x6(smith_x6), .smith_x7(smith_x7),
        .smith_y0(smith_y0), .smith_y1(smith_y1), .smith_y2(smith_y2), .smith_y3(smith_y3),
        .smith_y4(smith_y4), .smith_y5(smith_y5), .smith_y6(smith_y6), .smith_y7(smith_y7),
        .smith_active(smith_active),
        .npc_x0(npc_x0), .npc_x1(npc_x1), .npc_x2(npc_x2), .npc_x3(npc_x3),
        .npc_x4(npc_x4), .npc_x5(npc_x5), .npc_x6(npc_x6), .npc_x7(npc_x7),
        .npc_y0(npc_y0), .npc_y1(npc_y1), .npc_y2(npc_y2), .npc_y3(npc_y3),
        .npc_y4(npc_y4), .npc_y5(npc_y5), .npc_y6(npc_y6), .npc_y7(npc_y7),
        .npc_alive(npc_alive), .smith_chasing(smith_chasing),
        .use_ammo(combat_use_ammo), .use_charge(combat_use_charge), .use_emp(combat_use_emp),
        .smith_kill_mask(combat_smith_kill), .smith_stun_mask(combat_smith_stun),
        .replicate_en(combat_replicate_en), .replicate_npc_idx(combat_replicate_idx),
        .bullet_x0(bullet_x0), .bullet_x1(bullet_x1), .bullet_x2(bullet_x2), .bullet_x3(bullet_x3),
        .bullet_y0(bullet_y0), .bullet_y1(bullet_y1), .bullet_y2(bullet_y2), .bullet_y3(bullet_y3),
        .bullet_dir0(bullet_dir0), .bullet_dir1(bullet_dir1), .bullet_dir2(bullet_dir2), .bullet_dir3(bullet_dir3),
        .bullet_active(bullet_active),
        .bomb_x0(bomb_x0), .bomb_x1(bomb_x1), .bomb_x2(bomb_x2), .bomb_x3(bomb_x3),
        .bomb_y0(bomb_y0), .bomb_y1(bomb_y1), .bomb_y2(bomb_y2), .bomb_y3(bomb_y3),
        .bomb_timer0(bomb_timer0), .bomb_timer1(bomb_timer1), .bomb_timer2(bomb_timer2), .bomb_timer3(bomb_timer3),
        .bomb_active(bomb_active),
        .destroy_en(map_destroy_en), .destroy_tx(map_destroy_tx), .destroy_ty(map_destroy_ty),
        .emp_visual(emp_visual), .start_level(start_level_pulse)
    );

    reg  [4:0] text_msg_id;
    reg  [9:0] text_origin_x;
    reg  [9:0] text_origin_y;
    reg  [1:0] text_scale;
    wire text_hit;
    always @(*) begin
        text_msg_id = 5'd0;
        text_origin_x = 10'd200;
        text_origin_y = 10'd80;
        text_scale = 2'd1;
        case (state)
            ST_START: begin
                text_msg_id = 5'd0;
                text_origin_x = 10'd200;
                text_origin_y = 10'd80;
                text_scale = 2'd2;
            end
            ST_LOAD: begin
                text_msg_id = 5'd0;
                text_origin_x = 10'd200;
                text_origin_y = 10'd80;
                text_scale = 2'd2;
            end
            ST_WIN: begin
                text_msg_id = 5'd4;
                text_origin_x = 10'd250;
                text_origin_y = 10'd200;
                text_scale = 2'd2;
            end
            ST_LOSE: begin
                text_msg_id = 5'd5;
                text_origin_x = 10'd240;
                text_origin_y = 10'd200;
                text_scale = 2'd2;
            end
            default: begin
                case (quest_phase)
                    2'd0: begin text_msg_id = 5'd6; text_origin_x = 10'd20; text_origin_y = 10'd460; text_scale = 2'd0; end
                    2'd1: begin text_msg_id = 5'd7; text_origin_x = 10'd20; text_origin_y = 10'd460; text_scale = 2'd0; end
                    2'd2: begin text_msg_id = 5'd8; text_origin_x = 10'd20; text_origin_y = 10'd460; text_scale = 2'd0; end
                    default: begin text_msg_id = 5'd9; text_origin_x = 10'd20; text_origin_y = 10'd460; text_scale = 2'd0; end
                endcase
            end
        endcase
    end

    wire [3:0] render_r, render_g, render_b;
    (* keep = "true" *) reg        selected_video_q;
    (* keep = "true" *) reg [2:0]  state_video_q;
    (* keep = "true" *) reg [7:0]  move_phase_video_q;
    (* keep = "true" *) reg [15:0] frame_count_video_q;
    (* keep = "true" *) reg [9:0]  neo_x_video_q;
    (* keep = "true" *) reg [8:0]  neo_y_video_q;
    (* keep = "true" *) reg [1:0]  neo_dir_video_q;
    (* keep = "true" *) reg [7:0]  attract_timer_video_q;
    (* keep = "true" *) reg [8:0]  bt_timer_video_q;
    (* keep = "true" *) reg [3:0]  ammo_tens_video_q;
    (* keep = "true" *) reg [3:0]  ammo_ones_video_q;
    (* keep = "true" *) reg [2:0]  charges_video_q;
    (* keep = "true" *) reg [1:0]  emp_count_video_q;
    (* keep = "true" *) reg [1:0]  quest_phase_video_q;
    (* keep = "true" *) reg [2:0]  rescued_video_q;
    (* keep = "true" *) reg [2:0]  rescue_goal_video_q;
    (* keep = "true" *) reg        trinity_found_video_q;
    (* keep = "true" *) reg        terminal_hacked_video_q;
    (* keep = "true" *) reg [9:0]  smith_x0_video_q, smith_x1_video_q, smith_x2_video_q, smith_x3_video_q;
    (* keep = "true" *) reg [9:0]  smith_x4_video_q, smith_x5_video_q, smith_x6_video_q, smith_x7_video_q;
    (* keep = "true" *) reg [8:0]  smith_y0_video_q, smith_y1_video_q, smith_y2_video_q, smith_y3_video_q;
    (* keep = "true" *) reg [8:0]  smith_y4_video_q, smith_y5_video_q, smith_y6_video_q, smith_y7_video_q;
    (* keep = "true" *) reg [7:0]  smith_active_video_q;
    (* keep = "true" *) reg [7:0]  smith_chasing_video_q;
    (* keep = "true" *) reg [5:0]  smith_stun0_video_q, smith_stun1_video_q, smith_stun2_video_q, smith_stun3_video_q;
    (* keep = "true" *) reg [5:0]  smith_stun4_video_q, smith_stun5_video_q, smith_stun6_video_q, smith_stun7_video_q;
    (* keep = "true" *) reg [9:0]  npc_x0_video_q, npc_x1_video_q, npc_x2_video_q, npc_x3_video_q;
    (* keep = "true" *) reg [9:0]  npc_x4_video_q, npc_x5_video_q, npc_x6_video_q, npc_x7_video_q;
    (* keep = "true" *) reg [8:0]  npc_y0_video_q, npc_y1_video_q, npc_y2_video_q, npc_y3_video_q;
    (* keep = "true" *) reg [8:0]  npc_y4_video_q, npc_y5_video_q, npc_y6_video_q, npc_y7_video_q;
    (* keep = "true" *) reg [7:0]  npc_alive_video_q;
    (* keep = "true" *) reg [9:0]  red_x_video_q, trinity_x_video_q, terminal_x_video_q, phone_x_video_q;
    (* keep = "true" *) reg [8:0]  red_y_video_q, trinity_y_video_q, terminal_y_video_q, phone_y_video_q;
    (* keep = "true" *) reg [9:0]  bullet_x0_video_q, bullet_x1_video_q, bullet_x2_video_q, bullet_x3_video_q;
    (* keep = "true" *) reg [8:0]  bullet_y0_video_q, bullet_y1_video_q, bullet_y2_video_q, bullet_y3_video_q;
    (* keep = "true" *) reg [3:0]  bullet_active_video_q;
    (* keep = "true" *) reg [9:0]  bomb_x0_video_q, bomb_x1_video_q, bomb_x2_video_q, bomb_x3_video_q;
    (* keep = "true" *) reg [8:0]  bomb_y0_video_q, bomb_y1_video_q, bomb_y2_video_q, bomb_y3_video_q;
    (* keep = "true" *) reg [7:0]  bomb_timer0_video_q, bomb_timer1_video_q, bomb_timer2_video_q, bomb_timer3_video_q;
    (* keep = "true" *) reg [3:0]  bomb_active_video_q;
    (* keep = "true" *) reg [8:0]  emp_visual_video_q;
    (* keep = "true" *) reg [9:0]  pickup_x0_video_q, pickup_x1_video_q, pickup_x2_video_q, pickup_x3_video_q;
    (* keep = "true" *) reg [9:0]  pickup_x4_video_q, pickup_x5_video_q, pickup_x6_video_q, pickup_x7_video_q;
    (* keep = "true" *) reg [8:0]  pickup_y0_video_q, pickup_y1_video_q, pickup_y2_video_q, pickup_y3_video_q;
    (* keep = "true" *) reg [8:0]  pickup_y4_video_q, pickup_y5_video_q, pickup_y6_video_q, pickup_y7_video_q;
    (* keep = "true" *) reg [2:0]  pickup_type0_video_q, pickup_type1_video_q, pickup_type2_video_q, pickup_type3_video_q;
    (* keep = "true" *) reg [2:0]  pickup_type4_video_q, pickup_type5_video_q, pickup_type6_video_q, pickup_type7_video_q;
    (* keep = "true" *) reg [7:0]  pickup_active_video_q;
    (* keep = "true" *) reg [1:0]  menu_choice_video_q;
    (* keep = "true" *) reg [3:0]  start_difficulty_video_q;
    (* keep = "true" *) reg [3:0]  level_video_q;
    (* keep = "true" *) reg [4:0]  text_msg_id_video_q;
    (* keep = "true" *) reg [9:0]  text_origin_x_video_q;
    (* keep = "true" *) reg [9:0]  text_origin_y_video_q;
    (* keep = "true" *) reg [1:0]  text_scale_video_q;

    function [3:0] slot3_dec_tens6;
        input [5:0] value;
        begin
            if (value >= 6'd60) slot3_dec_tens6 = 4'd6;
            else if (value >= 6'd50) slot3_dec_tens6 = 4'd5;
            else if (value >= 6'd40) slot3_dec_tens6 = 4'd4;
            else if (value >= 6'd30) slot3_dec_tens6 = 4'd3;
            else if (value >= 6'd20) slot3_dec_tens6 = 4'd2;
            else if (value >= 6'd10) slot3_dec_tens6 = 4'd1;
            else slot3_dec_tens6 = 4'd0;
        end
    endfunction

    function [3:0] slot3_dec_ones6;
        input [5:0] value;
        begin
            if (value >= 6'd60) slot3_dec_ones6 = value - 6'd60;
            else if (value >= 6'd50) slot3_dec_ones6 = value - 6'd50;
            else if (value >= 6'd40) slot3_dec_ones6 = value - 6'd40;
            else if (value >= 6'd30) slot3_dec_ones6 = value - 6'd30;
            else if (value >= 6'd20) slot3_dec_ones6 = value - 6'd20;
            else if (value >= 6'd10) slot3_dec_ones6 = value - 6'd10;
            else slot3_dec_ones6 = value[3:0];
        end
    endfunction

    slot3_text u_text (
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .msg_id(text_msg_id_video_q),
        .origin_x(text_origin_x_video_q),
        .origin_y(text_origin_y_video_q),
        .scale(text_scale_video_q),
        .hit(text_hit)
    );

    always @(posedge clk) begin
        if (slot_reset_video) begin
            selected_video_q <= 1'b0;
            state_video_q <= ST_START;
            move_phase_video_q <= 8'd0;
            frame_count_video_q <= 16'd0;
            neo_x_video_q <= 10'd0;
            neo_y_video_q <= 9'd0;
            neo_dir_video_q <= 2'd0;
            attract_timer_video_q <= 8'd0;
            bt_timer_video_q <= 9'd0;
            ammo_tens_video_q <= 4'd0;
            ammo_ones_video_q <= 4'd0;
            charges_video_q <= 3'd0;
            emp_count_video_q <= 2'd0;
            quest_phase_video_q <= 2'd0;
            rescued_video_q <= 3'd0;
            rescue_goal_video_q <= 3'd0;
            trinity_found_video_q <= 1'b0;
            terminal_hacked_video_q <= 1'b0;
            smith_x0_video_q <= 10'd0; smith_x1_video_q <= 10'd0; smith_x2_video_q <= 10'd0; smith_x3_video_q <= 10'd0;
            smith_x4_video_q <= 10'd0; smith_x5_video_q <= 10'd0; smith_x6_video_q <= 10'd0; smith_x7_video_q <= 10'd0;
            smith_y0_video_q <= 9'd0; smith_y1_video_q <= 9'd0; smith_y2_video_q <= 9'd0; smith_y3_video_q <= 9'd0;
            smith_y4_video_q <= 9'd0; smith_y5_video_q <= 9'd0; smith_y6_video_q <= 9'd0; smith_y7_video_q <= 9'd0;
            smith_active_video_q <= 8'd0; smith_chasing_video_q <= 8'd0;
            smith_stun0_video_q <= 6'd0; smith_stun1_video_q <= 6'd0; smith_stun2_video_q <= 6'd0; smith_stun3_video_q <= 6'd0;
            smith_stun4_video_q <= 6'd0; smith_stun5_video_q <= 6'd0; smith_stun6_video_q <= 6'd0; smith_stun7_video_q <= 6'd0;
            npc_x0_video_q <= 10'd0; npc_x1_video_q <= 10'd0; npc_x2_video_q <= 10'd0; npc_x3_video_q <= 10'd0;
            npc_x4_video_q <= 10'd0; npc_x5_video_q <= 10'd0; npc_x6_video_q <= 10'd0; npc_x7_video_q <= 10'd0;
            npc_y0_video_q <= 9'd0; npc_y1_video_q <= 9'd0; npc_y2_video_q <= 9'd0; npc_y3_video_q <= 9'd0;
            npc_y4_video_q <= 9'd0; npc_y5_video_q <= 9'd0; npc_y6_video_q <= 9'd0; npc_y7_video_q <= 9'd0;
            npc_alive_video_q <= 8'd0;
            red_x_video_q <= 10'd0; trinity_x_video_q <= 10'd0; terminal_x_video_q <= 10'd0; phone_x_video_q <= 10'd0;
            red_y_video_q <= 9'd0; trinity_y_video_q <= 9'd0; terminal_y_video_q <= 9'd0; phone_y_video_q <= 9'd0;
            bullet_x0_video_q <= 10'd0; bullet_x1_video_q <= 10'd0; bullet_x2_video_q <= 10'd0; bullet_x3_video_q <= 10'd0;
            bullet_y0_video_q <= 9'd0; bullet_y1_video_q <= 9'd0; bullet_y2_video_q <= 9'd0; bullet_y3_video_q <= 9'd0;
            bullet_active_video_q <= 4'd0;
            bomb_x0_video_q <= 10'd0; bomb_x1_video_q <= 10'd0; bomb_x2_video_q <= 10'd0; bomb_x3_video_q <= 10'd0;
            bomb_y0_video_q <= 9'd0; bomb_y1_video_q <= 9'd0; bomb_y2_video_q <= 9'd0; bomb_y3_video_q <= 9'd0;
            bomb_timer0_video_q <= 8'd0; bomb_timer1_video_q <= 8'd0; bomb_timer2_video_q <= 8'd0; bomb_timer3_video_q <= 8'd0;
            bomb_active_video_q <= 4'd0;
            emp_visual_video_q <= 9'd0;
            pickup_x0_video_q <= 10'd0; pickup_x1_video_q <= 10'd0; pickup_x2_video_q <= 10'd0; pickup_x3_video_q <= 10'd0;
            pickup_x4_video_q <= 10'd0; pickup_x5_video_q <= 10'd0; pickup_x6_video_q <= 10'd0; pickup_x7_video_q <= 10'd0;
            pickup_y0_video_q <= 9'd0; pickup_y1_video_q <= 9'd0; pickup_y2_video_q <= 9'd0; pickup_y3_video_q <= 9'd0;
            pickup_y4_video_q <= 9'd0; pickup_y5_video_q <= 9'd0; pickup_y6_video_q <= 9'd0; pickup_y7_video_q <= 9'd0;
            pickup_type0_video_q <= 3'd0; pickup_type1_video_q <= 3'd0; pickup_type2_video_q <= 3'd0; pickup_type3_video_q <= 3'd0;
            pickup_type4_video_q <= 3'd0; pickup_type5_video_q <= 3'd0; pickup_type6_video_q <= 3'd0; pickup_type7_video_q <= 3'd0;
            pickup_active_video_q <= 8'd0;
            menu_choice_video_q <= 2'd0;
            start_difficulty_video_q <= 4'd1;
            level_video_q <= 4'd1;
            text_msg_id_video_q <= 5'd0;
            text_origin_x_video_q <= 10'd0;
            text_origin_y_video_q <= 10'd0;
            text_scale_video_q <= 2'd0;
        end else if (pixel_tick) begin
            selected_video_q <= selected;
            state_video_q <= state;
            move_phase_video_q <= move_phase;
            frame_count_video_q <= frame_count;
            neo_x_video_q <= neo_x;
            neo_y_video_q <= neo_y;
            neo_dir_video_q <= neo_dir;
            attract_timer_video_q <= attract_timer;
            bt_timer_video_q <= bt_timer;
            ammo_tens_video_q <= slot3_dec_tens6(ammo);
            ammo_ones_video_q <= slot3_dec_ones6(ammo);
            charges_video_q <= charges_w;
            emp_count_video_q <= emp_count;
            quest_phase_video_q <= quest_phase;
            rescued_video_q <= rescued;
            rescue_goal_video_q <= rescue_goal;
            trinity_found_video_q <= trinity_found;
            terminal_hacked_video_q <= terminal_hacked;
            smith_x0_video_q <= smith_x0; smith_x1_video_q <= smith_x1; smith_x2_video_q <= smith_x2; smith_x3_video_q <= smith_x3;
            smith_x4_video_q <= smith_x4; smith_x5_video_q <= smith_x5; smith_x6_video_q <= smith_x6; smith_x7_video_q <= smith_x7;
            smith_y0_video_q <= smith_y0; smith_y1_video_q <= smith_y1; smith_y2_video_q <= smith_y2; smith_y3_video_q <= smith_y3;
            smith_y4_video_q <= smith_y4; smith_y5_video_q <= smith_y5; smith_y6_video_q <= smith_y6; smith_y7_video_q <= smith_y7;
            smith_active_video_q <= smith_active; smith_chasing_video_q <= smith_chasing;
            smith_stun0_video_q <= smith_stun0; smith_stun1_video_q <= smith_stun1; smith_stun2_video_q <= smith_stun2; smith_stun3_video_q <= smith_stun3;
            smith_stun4_video_q <= smith_stun4; smith_stun5_video_q <= smith_stun5; smith_stun6_video_q <= smith_stun6; smith_stun7_video_q <= smith_stun7;
            npc_x0_video_q <= npc_x0; npc_x1_video_q <= npc_x1; npc_x2_video_q <= npc_x2; npc_x3_video_q <= npc_x3;
            npc_x4_video_q <= npc_x4; npc_x5_video_q <= npc_x5; npc_x6_video_q <= npc_x6; npc_x7_video_q <= npc_x7;
            npc_y0_video_q <= npc_y0; npc_y1_video_q <= npc_y1; npc_y2_video_q <= npc_y2; npc_y3_video_q <= npc_y3;
            npc_y4_video_q <= npc_y4; npc_y5_video_q <= npc_y5; npc_y6_video_q <= npc_y6; npc_y7_video_q <= npc_y7;
            npc_alive_video_q <= npc_alive;
            red_x_video_q <= red_x; trinity_x_video_q <= trinity_x; terminal_x_video_q <= terminal_x; phone_x_video_q <= phone_x;
            red_y_video_q <= red_y; trinity_y_video_q <= trinity_y; terminal_y_video_q <= terminal_y; phone_y_video_q <= phone_y;
            bullet_x0_video_q <= bullet_x0; bullet_x1_video_q <= bullet_x1; bullet_x2_video_q <= bullet_x2; bullet_x3_video_q <= bullet_x3;
            bullet_y0_video_q <= bullet_y0; bullet_y1_video_q <= bullet_y1; bullet_y2_video_q <= bullet_y2; bullet_y3_video_q <= bullet_y3;
            bullet_active_video_q <= bullet_active;
            bomb_x0_video_q <= bomb_x0; bomb_x1_video_q <= bomb_x1; bomb_x2_video_q <= bomb_x2; bomb_x3_video_q <= bomb_x3;
            bomb_y0_video_q <= bomb_y0; bomb_y1_video_q <= bomb_y1; bomb_y2_video_q <= bomb_y2; bomb_y3_video_q <= bomb_y3;
            bomb_timer0_video_q <= bomb_timer0; bomb_timer1_video_q <= bomb_timer1; bomb_timer2_video_q <= bomb_timer2; bomb_timer3_video_q <= bomb_timer3;
            bomb_active_video_q <= bomb_active;
            emp_visual_video_q <= emp_visual;
            pickup_x0_video_q <= pickup_x0; pickup_x1_video_q <= pickup_x1; pickup_x2_video_q <= pickup_x2; pickup_x3_video_q <= pickup_x3;
            pickup_x4_video_q <= pickup_x4; pickup_x5_video_q <= pickup_x5; pickup_x6_video_q <= pickup_x6; pickup_x7_video_q <= pickup_x7;
            pickup_y0_video_q <= pickup_y0; pickup_y1_video_q <= pickup_y1; pickup_y2_video_q <= pickup_y2; pickup_y3_video_q <= pickup_y3;
            pickup_y4_video_q <= pickup_y4; pickup_y5_video_q <= pickup_y5; pickup_y6_video_q <= pickup_y6; pickup_y7_video_q <= pickup_y7;
            pickup_type0_video_q <= pickup_type0; pickup_type1_video_q <= pickup_type1; pickup_type2_video_q <= pickup_type2; pickup_type3_video_q <= pickup_type3;
            pickup_type4_video_q <= pickup_type4; pickup_type5_video_q <= pickup_type5; pickup_type6_video_q <= pickup_type6; pickup_type7_video_q <= pickup_type7;
            pickup_active_video_q <= pickup_active;
            menu_choice_video_q <= menu_choice;
            start_difficulty_video_q <= start_difficulty;
            level_video_q <= level;
            text_msg_id_video_q <= text_msg_id;
            text_origin_x_video_q <= text_origin_x;
            text_origin_y_video_q <= text_origin_y;
            text_scale_video_q <= text_scale;
        end
    end

    always @(posedge clk) begin
        if (slot_reset_video) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end else if (pixel_tick) begin
            vga_r <= render_r;
            vga_g <= render_g;
            vga_b <= render_b;
        end
    end

    slot3_renderer u_renderer (
        .clk(clk),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .display_active(display_active), .selected(selected_video_q),
        .state(state_video_q), .render_tile(render_tile),
        .move_phase(move_phase_video_q), .frame_count(frame_count_video_q),
        .neo_x(neo_x_video_q), .neo_y(neo_y_video_q), .neo_dir(neo_dir_video_q),
        .attract_timer(attract_timer_video_q), .bt_timer(bt_timer_video_q), .cloak_timer(9'd0),
        .ammo_tens(ammo_tens_video_q), .ammo_ones(ammo_ones_video_q),
        .charges(charges_video_q), .emp_count(emp_count_video_q),
        .quest_phase(quest_phase_video_q), .rescued(rescued_video_q), .rescue_goal(rescue_goal_video_q),
        .trinity_found(trinity_found_video_q), .terminal_hacked(terminal_hacked_video_q),
        .smith_x0(smith_x0_video_q), .smith_x1(smith_x1_video_q), .smith_x2(smith_x2_video_q), .smith_x3(smith_x3_video_q),
        .smith_x4(smith_x4_video_q), .smith_x5(smith_x5_video_q), .smith_x6(smith_x6_video_q), .smith_x7(smith_x7_video_q),
        .smith_y0(smith_y0_video_q), .smith_y1(smith_y1_video_q), .smith_y2(smith_y2_video_q), .smith_y3(smith_y3_video_q),
        .smith_y4(smith_y4_video_q), .smith_y5(smith_y5_video_q), .smith_y6(smith_y6_video_q), .smith_y7(smith_y7_video_q),
        .smith_active(smith_active_video_q), .smith_chasing(smith_chasing_video_q),
        .smith_stun0(smith_stun0_video_q), .smith_stun1(smith_stun1_video_q), .smith_stun2(smith_stun2_video_q), .smith_stun3(smith_stun3_video_q),
        .smith_stun4(smith_stun4_video_q), .smith_stun5(smith_stun5_video_q), .smith_stun6(smith_stun6_video_q), .smith_stun7(smith_stun7_video_q),
        .npc_x0(npc_x0_video_q), .npc_x1(npc_x1_video_q), .npc_x2(npc_x2_video_q), .npc_x3(npc_x3_video_q),
        .npc_x4(npc_x4_video_q), .npc_x5(npc_x5_video_q), .npc_x6(npc_x6_video_q), .npc_x7(npc_x7_video_q),
        .npc_y0(npc_y0_video_q), .npc_y1(npc_y1_video_q), .npc_y2(npc_y2_video_q), .npc_y3(npc_y3_video_q),
        .npc_y4(npc_y4_video_q), .npc_y5(npc_y5_video_q), .npc_y6(npc_y6_video_q), .npc_y7(npc_y7_video_q),
        .npc_alive(npc_alive_video_q),
        .red_x(red_x_video_q), .red_y(red_y_video_q),
        .trinity_x(trinity_x_video_q), .trinity_y(trinity_y_video_q),
        .terminal_x(terminal_x_video_q), .terminal_y(terminal_y_video_q),
        .phone_x(phone_x_video_q), .phone_y(phone_y_video_q),
        .bullet_x0(bullet_x0_video_q), .bullet_x1(bullet_x1_video_q), .bullet_x2(bullet_x2_video_q), .bullet_x3(bullet_x3_video_q),
        .bullet_y0(bullet_y0_video_q), .bullet_y1(bullet_y1_video_q), .bullet_y2(bullet_y2_video_q), .bullet_y3(bullet_y3_video_q),
        .bullet_active(bullet_active_video_q),
        .bomb_x0(bomb_x0_video_q), .bomb_x1(bomb_x1_video_q), .bomb_x2(bomb_x2_video_q), .bomb_x3(bomb_x3_video_q),
        .bomb_y0(bomb_y0_video_q), .bomb_y1(bomb_y1_video_q), .bomb_y2(bomb_y2_video_q), .bomb_y3(bomb_y3_video_q),
        .bomb_timer0(bomb_timer0_video_q), .bomb_timer1(bomb_timer1_video_q), .bomb_timer2(bomb_timer2_video_q), .bomb_timer3(bomb_timer3_video_q),
        .bomb_active(bomb_active_video_q),
        .emp_visual(emp_visual_video_q),
        .pickup_x0(pickup_x0_video_q), .pickup_x1(pickup_x1_video_q), .pickup_x2(pickup_x2_video_q), .pickup_x3(pickup_x3_video_q),
        .pickup_x4(pickup_x4_video_q), .pickup_x5(pickup_x5_video_q), .pickup_x6(pickup_x6_video_q), .pickup_x7(pickup_x7_video_q),
        .pickup_y0(pickup_y0_video_q), .pickup_y1(pickup_y1_video_q), .pickup_y2(pickup_y2_video_q), .pickup_y3(pickup_y3_video_q),
        .pickup_y4(pickup_y4_video_q), .pickup_y5(pickup_y5_video_q), .pickup_y6(pickup_y6_video_q), .pickup_y7(pickup_y7_video_q),
        .pickup_type0(pickup_type0_video_q), .pickup_type1(pickup_type1_video_q), .pickup_type2(pickup_type2_video_q), .pickup_type3(pickup_type3_video_q),
        .pickup_type4(pickup_type4_video_q), .pickup_type5(pickup_type5_video_q), .pickup_type6(pickup_type6_video_q), .pickup_type7(pickup_type7_video_q),
        .pickup_active(pickup_active_video_q),
        .menu_choice(menu_choice_video_q), .start_difficulty(start_difficulty_video_q),
        .pill_choice(1'b0), .level(level_video_q),
        .text_hit(text_hit),
        .vga_r(render_r), .vga_g(render_g), .vga_b(render_b)
    );

    wire [9:0] sx [0:7];
    wire [8:0] sy [0:7];
    assign sx[0]=smith_x0; assign sx[1]=smith_x1; assign sx[2]=smith_x2; assign sx[3]=smith_x3;
    assign sx[4]=smith_x4; assign sx[5]=smith_x5; assign sx[6]=smith_x6; assign sx[7]=smith_x7;
    assign sy[0]=smith_y0; assign sy[1]=smith_y1; assign sy[2]=smith_y2; assign sy[3]=smith_y3;
    assign sy[4]=smith_y4; assign sy[5]=smith_y5; assign sy[6]=smith_y6; assign sy[7]=smith_y7;

    reg neo_hit_smith;
    integer hi;
    always @(*) begin
        neo_hit_smith = 1'b0;
        for (hi = 0; hi < 8; hi = hi + 1) begin
            if (smith_active[hi] &&
                (neo_x < sx[hi] + 10'd16) && (neo_x + 10'd16 > sx[hi]) &&
                (neo_y < sy[hi] + 9'd20) && (neo_y + 9'd20 > sy[hi])) begin
                neo_hit_smith = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (slot_reset_ctrl) begin
            lfsr <= 32'h4D595DF4;
        end else if (frame_tick_q) begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[29] ^ lfsr[25] ^ lfsr[24]};
        end
    end

    always @(posedge clk) begin
        if (slot_reset_ctrl) begin
            state <= ST_START;
            menu_choice <= 2'd0;
            start_difficulty <= 4'd1;
            level <= 4'd1;
            frame_count <= 16'd0;
            move_phase <= 8'd0;
            start_level_req <= 1'b0;
            start_level_d <= 1'b0;
        end else begin
            start_level_d <= start_level_req;
            if (start_level_req) start_level_req <= 1'b0;

            if (frame_tick_q) begin
                frame_count <= frame_count + 16'd1;
                move_phase <= move_phase + 8'd1;
            end

            case (state)
                ST_START: begin
                    if (input_up && frame_tick_q && move_phase[4:0] == 5'd0)
                        menu_choice <= (menu_choice == 2'd0) ? 2'd1 : menu_choice - 2'd1;
                    if (input_down && frame_tick_q && move_phase[4:0] == 5'd0)
                        menu_choice <= (menu_choice == 2'd1) ? 2'd0 : menu_choice + 2'd1;
                    if (menu_choice == 2'd1 && input_left && frame_tick_q && move_phase[4:0] == 5'd0)
                        start_difficulty <= (start_difficulty > 4'd1) ? start_difficulty - 4'd1 : 4'd1;
                    if (menu_choice == 2'd1 && input_right && frame_tick_q && move_phase[4:0] == 5'd0)
                        start_difficulty <= (start_difficulty < 4'd5) ? start_difficulty + 4'd1 : 4'd5;
                    if (confirm_pulse) begin
                        if (menu_choice == 2'd0) begin
                            level <= start_difficulty;
                            start_level_req <= 1'b1;
                            state <= ST_LOAD;
                        end else if (menu_choice == 2'd1) begin
                            start_difficulty <= (start_difficulty == 4'd5) ? 4'd1 : start_difficulty + 4'd1;
                        end
                    end
                end
                ST_LOAD: begin
                    if (esc_pulse) state <= ST_START;
                    else if (map_gen_done) state <= ST_PLAY;
                end
                ST_PLAY: begin
                    if (esc_pulse) state <= ST_START;
                    else if (neo_hit_smith) state <= ST_LOSE;
                    else if (neo_touch_phone && phone_reachable) state <= ST_WIN;
                end
                ST_WIN: begin
                    if (confirm_pulse || esc_pulse) state <= ST_START;
                end
                ST_LOSE: begin
                    if (confirm_pulse || esc_pulse) state <= ST_START;
                end
                default: state <= ST_START;
            endcase
        end
    end

endmodule
