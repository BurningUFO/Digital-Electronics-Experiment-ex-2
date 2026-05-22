module slot3_player (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [7:0]  move_phase,
    input  wire        input_up,
    input  wire        input_down,
    input  wire        input_left,
    input  wire        input_right,
    input  wire        space_pulse,
    input  wire        bullet_time_active,
    input  wire        walkable,
    input  wire        walkable_x,
    input  wire        walkable_y,
    output reg  [9:0]  neo_x,
    output reg  [8:0]  neo_y,
    output reg  [1:0]  neo_dir,
    output reg  [9:0]  try_x,
    output reg  [8:0]  try_y,
    output reg  [9:0]  try_xx,
    output reg  [8:0]  try_xy,
    output reg  [9:0]  try_yx,
    output reg  [8:0]  try_yy,
    output reg         has_bullet_time,
    output reg  [8:0]  bt_timer,
    output reg  [8:0]  bt_cooldown,
    output reg  [7:0]  attract_timer,
    output reg  [8:0]  cloak_timer,
    output reg  [5:0]  ammo,
    output reg  [2:0]  charges,
    output reg  [1:0]  emp_count,
    output reg  [1:0]  cloak_count,
    output reg  [1:0]  map_fragments,
    output reg  [2:0]  phone_cards,
    output reg  [2:0]  rescued,
    input  wire        give_bullet_time,
    input  wire        give_ammo,
    input  wire        give_charge,
    input  wire        give_emp,
    input  wire        give_cloak,
    input  wire        give_map,
    input  wire        give_phonecard,
    input  wire        do_attract,
    input  wire        do_rescue,
    input  wire        start_level
);

    localparam [9:0] WORLD_W = 10'd640;
    localparam [8:0] WORLD_H = 9'd480;
    localparam [9:0] NEO_W   = 10'd16;
    localparam [8:0] NEO_H   = 9'd20;
    localparam [9:0] SPEED   = 10'd3;
    localparam [9:0] SPEED_DIAG = 10'd2; // 3/sqrt(2) ~ 2.12

    reg [9:0] next_x;
    reg [8:0] next_y;
    reg [9:0] next_x_only;
    reg [8:0] next_y_only;
    reg input_up_q;
    reg input_down_q;
    reg input_left_q;
    reg input_right_q;
    reg move_pending;
    reg move_commit_pending;
    reg walkable_q;
    reg walkable_x_q;
    reg walkable_y_q;
    reg [1:0] pending_dir;

    wire move_tick = frame_tick && (move_phase[0] == 1'b0);
    wire can_move = playing && (attract_timer == 8'd0);
    wire moving_x = input_left_q || input_right_q;
    wire moving_y = input_up_q || input_down_q;
    wire diagonal = moving_x && moving_y;
    wire [9:0] spd = diagonal ? SPEED_DIAG : SPEED;
    wire [1:0] requested_dir = input_up_q    ? 2'd0 :
                               input_right_q ? 2'd1 :
                               input_down_q  ? 2'd2 :
                               input_left_q  ? 2'd3 :
                                                neo_dir;

    always @(*) begin
        next_x = neo_x;
        next_y = neo_y;
        next_x_only = neo_x;
        next_y_only = neo_y;
        if (can_move) begin
            if (input_left_q && neo_x >= spd)
                begin next_x = neo_x - spd; next_x_only = neo_x - spd; end
            else if (input_right_q && neo_x < WORLD_W - NEO_W - spd)
                begin next_x = neo_x + spd; next_x_only = neo_x + spd; end
            if (input_up_q && neo_y >= spd[8:0])
                begin next_y = neo_y - spd[8:0]; next_y_only = neo_y - spd[8:0]; end
            else if (input_down_q && neo_y < WORLD_H - NEO_H - spd[8:0])
                begin next_y = neo_y + spd[8:0]; next_y_only = neo_y + spd[8:0]; end
        end
    end

    always @(posedge clk) begin
        if (reset || start_level) begin
            neo_x <= 10'd48;
            neo_y <= 9'd384;
            neo_dir <= 2'd1;
            try_x <= 10'd48;
            try_y <= 9'd384;
            try_xx <= 10'd48;
            try_xy <= 9'd384;
            try_yx <= 10'd48;
            try_yy <= 9'd384;
            move_pending <= 1'b0;
            move_commit_pending <= 1'b0;
            walkable_q <= 1'b0;
            walkable_x_q <= 1'b0;
            walkable_y_q <= 1'b0;
            pending_dir <= 2'd1;
            has_bullet_time <= 1'b0;
            bt_timer <= 9'd0;
            bt_cooldown <= 9'd0;
            attract_timer <= 8'd0;
            cloak_timer <= 9'd0;
            ammo <= 6'd0;
            charges <= 3'd0;
            emp_count <= 2'd0;
            cloak_count <= 2'd0;
            map_fragments <= 2'd0;
            phone_cards <= 3'd0;
            rescued <= 3'd0;
            input_up_q <= 1'b0;
            input_down_q <= 1'b0;
            input_left_q <= 1'b0;
            input_right_q <= 1'b0;
        end else begin
            input_up_q <= input_up;
            input_down_q <= input_down;
            input_left_q <= input_left;
            input_right_q <= input_right;

            if (frame_tick) begin
                if (bt_timer != 9'd0) bt_timer <= bt_timer - 9'd1;
                if (bt_cooldown != 9'd0) bt_cooldown <= bt_cooldown - 9'd1;
                if (attract_timer != 8'd0) attract_timer <= attract_timer - 8'd1;
                if (cloak_timer != 9'd0) cloak_timer <= cloak_timer - 9'd1;
            end

            if (move_pending) begin
                walkable_q <= walkable;
                walkable_x_q <= walkable_x;
                walkable_y_q <= walkable_y;
                move_pending <= 1'b0;
                move_commit_pending <= 1'b1;
            end

            if (move_commit_pending) begin
                if (walkable_q) begin
                    neo_x <= try_x;
                    neo_y <= try_y;
                end else if (walkable_x_q) begin
                    neo_x <= try_xx;
                end else if (walkable_y_q) begin
                    neo_y <= try_yy;
                end

                neo_dir <= pending_dir;
                move_commit_pending <= 1'b0;
            end

            if (move_tick && can_move && (moving_x || moving_y) && !move_pending && !move_commit_pending) begin
                try_x <= next_x;
                try_y <= next_y;
                try_xx <= next_x_only;
                try_xy <= neo_y;
                try_yx <= neo_x;
                try_yy <= next_y_only;
                pending_dir <= requested_dir;
                move_pending <= 1'b1;
            end

            if (space_pulse && has_bullet_time && bt_timer == 9'd0 && bt_cooldown == 9'd0) begin
                bt_timer <= 9'd260;
                bt_cooldown <= 9'd420;
            end

            if (give_bullet_time) has_bullet_time <= 1'b1;
            if (give_ammo)        ammo <= ammo + 6'd12;
            if (give_charge)      charges <= charges + 3'd1;
            if (give_emp)         emp_count <= emp_count + 2'd1;
            if (give_cloak)       cloak_count <= cloak_count + 2'd1;
            if (give_map)         map_fragments <= (map_fragments < 2'd3) ? map_fragments + 2'd1 : 2'd3;
            if (give_phonecard)   phone_cards <= phone_cards + 3'd1;
            if (do_attract && attract_timer == 8'd0)
                attract_timer <= 8'd170;
            if (do_rescue)        rescued <= rescued + 3'd1;
        end
    end

endmodule
