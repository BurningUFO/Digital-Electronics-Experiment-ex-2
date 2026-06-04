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
    output reg  [9:0]  neo_x,
    output reg  [8:0]  neo_y,
    output reg  [1:0]  neo_dir,
    output reg  [9:0]  try_x,
    output reg  [8:0]  try_y,
    output reg         has_bullet_time,
    output reg  [8:0]  bt_timer,
    output reg  [8:0]  bt_cooldown,
    output reg  [7:0]  attract_timer,
    output reg  [5:0]  ammo,
    output reg  [2:0]  rescued,
    input  wire        give_bullet_time,
    input  wire        give_ammo,
    input  wire        do_attract,
    input  wire        do_rescue,
    input  wire        start_level
);

    localparam [9:0] WORLD_W = 10'd640;
    localparam [8:0] WORLD_H = 9'd480;
    localparam [9:0] NEO_W   = 10'd16;
    localparam [8:0] NEO_H   = 9'd20;
    localparam [9:0] SPEED   = 10'd4;
    localparam [8:0] BT_TIME = 9'd150;
    localparam [8:0] BT_CD   = 9'd300;
    localparam [7:0] ATTRACT_TIME = 8'd80;

    reg input_up_q;
    reg input_down_q;
    reg input_left_q;
    reg input_right_q;
    reg [9:0] candidate_x;
    reg [8:0] candidate_y;
    reg move_req;

    always @(*) begin
        candidate_x = neo_x;
        candidate_y = neo_y;
        move_req = 1'b0;

        if (playing && (attract_timer == 8'd0 || bullet_time_active || attract_timer != 8'd0)) begin
            if (input_up_q) begin
                move_req = 1'b1;
                candidate_y = (neo_y >= SPEED[8:0]) ? (neo_y - SPEED[8:0]) : 9'd0;
            end else if (input_right_q) begin
                move_req = 1'b1;
                candidate_x = (neo_x < WORLD_W - NEO_W - SPEED) ? (neo_x + SPEED) : (WORLD_W - NEO_W);
            end else if (input_down_q) begin
                move_req = 1'b1;
                candidate_y = (neo_y < WORLD_H - NEO_H - SPEED[8:0]) ? (neo_y + SPEED[8:0]) : (WORLD_H - NEO_H);
            end else if (input_left_q) begin
                move_req = 1'b1;
                candidate_x = (neo_x >= SPEED) ? (neo_x - SPEED) : 10'd0;
            end
        end
    end

    always @(posedge clk) begin
        if (reset || start_level) begin
            neo_x <= 10'd48;
            neo_y <= 9'd384;
            neo_dir <= 2'd1;
            try_x <= 10'd48;
            try_y <= 9'd384;
            has_bullet_time <= 1'b0;
            bt_timer <= 9'd0;
            bt_cooldown <= 9'd0;
            attract_timer <= 8'd0;
            ammo <= 6'd8;
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

                try_x <= candidate_x;
                try_y <= candidate_y;

                if (move_req && walkable) begin
                    neo_x <= candidate_x;
                    neo_y <= candidate_y;
                    if (input_up_q) neo_dir <= 2'd0;
                    else if (input_right_q) neo_dir <= 2'd1;
                    else if (input_down_q) neo_dir <= 2'd2;
                    else if (input_left_q) neo_dir <= 2'd3;
                end
            end

            if (space_pulse && has_bullet_time && bt_timer == 9'd0 && bt_cooldown == 9'd0) begin
                bt_timer <= BT_TIME;
                bt_cooldown <= BT_CD;
            end

            if (give_bullet_time) has_bullet_time <= 1'b1;
            if (give_ammo && ammo <= 6'd51) ammo <= ammo + 6'd12;
            if (do_attract && attract_timer == 8'd0) attract_timer <= ATTRACT_TIME;
            if (do_rescue && rescued != 3'd7) rescued <= rescued + 3'd1;
        end
    end

endmodule
