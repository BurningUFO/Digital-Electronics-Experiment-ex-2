module slot3_entities (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [7:0]  move_phase,
    input  wire [31:0] lfsr,
    input  wire [3:0]  level,
    input  wire        bullet_time_active,
    input  wire [7:0]  attract_timer,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [1:0]  neo_dir,
    input  wire [3:0]  river_y,
    input  wire        start_level,
    input  wire [31:0] init_seed,
    input  wire [7:0]  smith_kill_mask,
    input  wire [7:0]  smith_stun_set,
    input  wire [7:0]  npc_rescue_mask,
    input  wire        replicate_en,
    input  wire [2:0]  replicate_npc_idx,
    output wire [9:0]  smith_x0, smith_x1, smith_x2, smith_x3,
    output wire [9:0]  smith_x4, smith_x5, smith_x6, smith_x7,
    output wire [8:0]  smith_y0, smith_y1, smith_y2, smith_y3,
    output wire [8:0]  smith_y4, smith_y5, smith_y6, smith_y7,
    output wire [1:0]  smith_type0, smith_type1, smith_type2, smith_type3,
    output wire [1:0]  smith_type4, smith_type5, smith_type6, smith_type7,
    output reg  [7:0]  smith_active,
    output wire [5:0]  smith_stun0, smith_stun1, smith_stun2, smith_stun3,
    output wire [5:0]  smith_stun4, smith_stun5, smith_stun6, smith_stun7,
    output wire [7:0]  smith_chasing,
    output wire [9:0]  npc_x0, npc_x1, npc_x2, npc_x3,
    output wire [9:0]  npc_x4, npc_x5, npc_x6, npc_x7,
    output wire [8:0]  npc_y0, npc_y1, npc_y2, npc_y3,
    output wire [8:0]  npc_y4, npc_y5, npc_y6, npc_y7,
    output reg  [7:0]  npc_alive,
    output reg  [9:0]  red_x,
    output reg  [8:0]  red_y,
    output reg  [9:0]  trinity_x,
    output reg  [8:0]  trinity_y
);

    localparam [9:0] WORLD_W = 10'd640;
    localparam [8:0] WORLD_H = 9'd480;
    localparam [9:0] SMITH_W = 10'd16;
    localparam [8:0] SMITH_H = 9'd20;
    localparam [9:0] NPC_W = 10'd15;
    localparam [8:0] NPC_H = 9'd19;
    localparam [3:0] MAX_SMITH = 4'd3;

    reg [9:0] smith_x [0:7];
    reg [8:0] smith_y [0:7];
    reg [1:0] smith_type [0:7];
    reg [5:0] smith_stun [0:7];
    reg [5:0] smith_alert [0:7];
    reg [9:0] npc_x [0:7];
    reg [8:0] npc_y [0:7];
    reg [7:0] chase_reg;

    assign smith_x0=smith_x[0]; assign smith_x1=smith_x[1]; assign smith_x2=smith_x[2]; assign smith_x3=smith_x[3];
    assign smith_x4=smith_x[4]; assign smith_x5=smith_x[5]; assign smith_x6=smith_x[6]; assign smith_x7=smith_x[7];
    assign smith_y0=smith_y[0]; assign smith_y1=smith_y[1]; assign smith_y2=smith_y[2]; assign smith_y3=smith_y[3];
    assign smith_y4=smith_y[4]; assign smith_y5=smith_y[5]; assign smith_y6=smith_y[6]; assign smith_y7=smith_y[7];
    assign smith_type0=smith_type[0]; assign smith_type1=smith_type[1]; assign smith_type2=smith_type[2]; assign smith_type3=smith_type[3];
    assign smith_type4=smith_type[4]; assign smith_type5=smith_type[5]; assign smith_type6=smith_type[6]; assign smith_type7=smith_type[7];
    assign smith_stun0=smith_stun[0]; assign smith_stun1=smith_stun[1]; assign smith_stun2=smith_stun[2]; assign smith_stun3=smith_stun[3];
    assign smith_stun4=smith_stun[4]; assign smith_stun5=smith_stun[5]; assign smith_stun6=smith_stun[6]; assign smith_stun7=smith_stun[7];
    assign npc_x0=npc_x[0]; assign npc_x1=npc_x[1]; assign npc_x2=npc_x[2]; assign npc_x3=npc_x[3];
    assign npc_x4=npc_x[4]; assign npc_x5=npc_x[5]; assign npc_x6=npc_x[6]; assign npc_x7=npc_x[7];
    assign npc_y0=npc_y[0]; assign npc_y1=npc_y[1]; assign npc_y2=npc_y[2]; assign npc_y3=npc_y[3];
    assign npc_y4=npc_y[4]; assign npc_y5=npc_y[5]; assign npc_y6=npc_y[6]; assign npc_y7=npc_y[7];
    assign smith_chasing = chase_reg;

    function [3:0] smith_count;
        input [7:0] active_mask;
        begin
            smith_count = {3'b000, active_mask[0]} + {3'b000, active_mask[1]} +
                          {3'b000, active_mask[2]} + {3'b000, active_mask[3]} +
                          {3'b000, active_mask[4]} + {3'b000, active_mask[5]} +
                          {3'b000, active_mask[6]} + {3'b000, active_mask[7]};
        end
    endfunction

    wire smith_move_tick = frame_tick && (bullet_time_active ? (move_phase[2:0] == 3'd0) : (move_phase[1:0] == 2'd0));
    wire red_move_tick = frame_tick && (move_phase[3:0] == 4'd0);
    wire npc_move_tick = frame_tick && (move_phase[3:0] == 4'd0);

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                smith_x[i] <= 10'd700;
                smith_y[i] <= 9'd500;
                smith_type[i] <= 2'd0;
                smith_stun[i] <= 6'd0;
                smith_alert[i] <= 6'd0;
                npc_x[i] <= 10'd0;
                npc_y[i] <= 9'd0;
            end
            smith_active <= 8'd0;
            npc_alive <= 8'd0;
            red_x <= 10'd320;
            red_y <= 9'd240;
            trinity_x <= 10'd112;
            trinity_y <= 9'd96;
            chase_reg <= 8'd0;
        end else if (start_level) begin
            smith_x[0] <= 10'd520; smith_y[0] <= 9'd320;
            smith_x[1] <= 10'd400; smith_y[1] <= 9'd112;
            smith_x[2] <= 10'd528; smith_y[2] <= 9'd208;
            for (i = 3; i < 8; i = i + 1) begin
                smith_x[i] <= 10'd700;
                smith_y[i] <= 9'd500;
            end
            smith_type[0] <= 2'd0;
            smith_type[1] <= 2'd1;
            smith_type[2] <= 2'd2;
            for (i = 3; i < 8; i = i + 1) smith_type[i] <= 2'd0;
            smith_active <= (level >= 4'd4) ? 8'b00000111 :
                            (level >= 4'd2) ? 8'b00000011 :
                                              8'b00000001;
            for (i = 0; i < 8; i = i + 1) begin
                smith_stun[i] <= 6'd0;
                smith_alert[i] <= 6'd0;
            end

            case (init_seed[1:0])
                2'd0: begin
                    trinity_x <= 10'd96; trinity_y <= 9'd80;
                    red_x <= 10'd288; red_y <= 9'd176;
                    npc_x[0] <= 10'd176; npc_y[0] <= 9'd320;
                    npc_x[1] <= 10'd464; npc_y[1] <= 9'd96;
                end
                2'd1: begin
                    trinity_x <= 10'd480; trinity_y <= 9'd112;
                    red_x <= 10'd240; red_y <= 9'd304;
                    npc_x[0] <= 10'd128; npc_y[0] <= 9'd352;
                    npc_x[1] <= 10'd400; npc_y[1] <= 9'd224;
                end
                2'd2: begin
                    trinity_x <= 10'd144; trinity_y <= 9'd240;
                    red_x <= 10'd432; red_y <= 9'd144;
                    npc_x[0] <= 10'd224; npc_y[0] <= 9'd112;
                    npc_x[1] <= 10'd496; npc_y[1] <= 9'd336;
                end
                default: begin
                    trinity_x <= 10'd352; trinity_y <= 9'd288;
                    red_x <= 10'd160; red_y <= 9'd176;
                    npc_x[0] <= 10'd112; npc_y[0] <= 9'd144;
                    npc_x[1] <= 10'd448; npc_y[1] <= 9'd352;
                end
            endcase
            npc_alive <= 8'b00000011;
            for (i = 2; i < 8; i = i + 1) begin
                npc_x[i] <= 10'd0;
                npc_y[i] <= 9'd0;
            end
            chase_reg <= 8'd0;
        end else begin
            for (i = 0; i < 8; i = i + 1) begin
                if (smith_kill_mask[i]) begin
                    smith_active[i] <= 1'b0;
                    smith_x[i] <= 10'd700;
                    smith_y[i] <= 9'd500;
                    smith_alert[i] <= 6'd0;
                end
                if (smith_stun_set[i]) smith_stun[i] <= 6'd28;
                if (npc_rescue_mask[i]) npc_alive[i] <= 1'b0;
            end

            if (replicate_en && smith_count(smith_active) < MAX_SMITH && !smith_active[3]) begin
                smith_x[3] <= npc_x[replicate_npc_idx];
                smith_y[3] <= npc_y[replicate_npc_idx];
                smith_type[3] <= 2'd0;
                smith_stun[3] <= 6'd0;
                smith_alert[3] <= 6'd16;
                smith_active[3] <= 1'b1;
                npc_alive[replicate_npc_idx] <= 1'b0;
            end

            if (frame_tick) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_stun[i] != 6'd0) smith_stun[i] <= smith_stun[i] - 6'd1;
                    if (smith_alert[i] != 6'd0) smith_alert[i] <= smith_alert[i] - 6'd1;
                end
            end

            if (smith_move_tick && playing) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_active[i] && smith_stun[i] == 6'd0) begin
                        if ((((smith_x[i] > neo_x) ? (smith_x[i] - neo_x) : (neo_x - smith_x[i])) +
                             ((smith_y[i] > neo_y) ? (smith_y[i] - neo_y) : (neo_y - smith_y[i]))) < (attract_timer != 8'd0 ? 11'd220 : 11'd150)) begin
                            smith_alert[i] <= 6'd30;
                        end
                        chase_reg[i] <= (smith_alert[i] != 6'd0);

                        if (smith_alert[i] != 6'd0) begin
                            if (smith_x[i] + 10'd3 < neo_x && smith_x[i] < WORLD_W - SMITH_W - 10'd2)
                                smith_x[i] <= smith_x[i] + 10'd1;
                            else if (smith_x[i] > neo_x + 10'd3 && smith_x[i] > 10'd2)
                                smith_x[i] <= smith_x[i] - 10'd1;

                            if (smith_y[i] + 9'd3 < neo_y && smith_y[i] < WORLD_H - SMITH_H - 9'd2)
                                smith_y[i] <= smith_y[i] + 9'd1;
                            else if (smith_y[i] > neo_y + 9'd3 && smith_y[i] > 9'd2)
                                smith_y[i] <= smith_y[i] - 9'd1;
                        end else begin
                            if (lfsr[i]) smith_x[i] <= (smith_x[i] < WORLD_W - SMITH_W - 10'd2) ? smith_x[i] + 10'd1 : smith_x[i] - 10'd1;
                            else         smith_x[i] <= (smith_x[i] > 10'd2) ? smith_x[i] - 10'd1 : smith_x[i] + 10'd1;
                            if (lfsr[i + 8]) smith_y[i] <= (smith_y[i] < WORLD_H - SMITH_H - 9'd2) ? smith_y[i] + 9'd1 : smith_y[i] - 9'd1;
                            else             smith_y[i] <= (smith_y[i] > 9'd2) ? smith_y[i] - 9'd1 : smith_y[i] + 9'd1;
                        end
                    end else begin
                        chase_reg[i] <= 1'b0;
                    end
                end
            end

            if (npc_move_tick && playing) begin
                for (i = 0; i < 2; i = i + 1) begin
                    if (npc_alive[i]) begin
                        if (lfsr[i + 16]) npc_x[i] <= (npc_x[i] < WORLD_W - NPC_W - 10'd2) ? npc_x[i] + 10'd1 : npc_x[i] - 10'd1;
                        else              npc_x[i] <= (npc_x[i] > 10'd2) ? npc_x[i] - 10'd1 : npc_x[i] + 10'd1;
                    end
                end
            end

            if (red_move_tick && playing) begin
                if (lfsr[0]) red_x <= (red_x < WORLD_W - 10'd18) ? red_x + 10'd1 : red_x - 10'd1;
                else         red_x <= (red_x > 10'd2) ? red_x - 10'd1 : red_x + 10'd1;
                if (lfsr[1]) red_y <= (red_y < WORLD_H - 9'd22) ? red_y + 9'd1 : red_y - 9'd1;
                else         red_y <= (red_y > 9'd2) ? red_y - 9'd1 : red_y + 9'd1;
            end
        end
    end

endmodule
