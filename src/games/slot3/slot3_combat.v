// Combat and destructive actions for slot 3.
//
// Owns bullets, the single active bomb, EMP stun effects, resource-consume
// pulses, and the Smith/NPC replication scan.  Outputs are masks/events so the
// entity and map modules can apply state changes in their own clocked blocks.
module slot3_combat (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_tick,
    input  wire        playing,
    input  wire [7:0]  move_phase,
    input  wire        shoot_pulse,
    input  wire        bomb_pulse,
    input  wire        emp_pulse,
    input  wire [9:0]  neo_x,
    input  wire [8:0]  neo_y,
    input  wire [1:0]  neo_dir,
    input  wire [5:0]  ammo,
    input  wire [2:0]  charges,
    input  wire [1:0]  emp_count,
    input  wire        bullet_time_active,
    input  wire [9:0]  smith_x0, smith_x1, smith_x2, smith_x3,
    input  wire [9:0]  smith_x4, smith_x5, smith_x6, smith_x7,
    input  wire [8:0]  smith_y0, smith_y1, smith_y2, smith_y3,
    input  wire [8:0]  smith_y4, smith_y5, smith_y6, smith_y7,
    input  wire [7:0]  smith_active,
    input  wire [9:0]  npc_x0, npc_x1, npc_x2, npc_x3,
    input  wire [9:0]  npc_x4, npc_x5, npc_x6, npc_x7,
    input  wire [8:0]  npc_y0, npc_y1, npc_y2, npc_y3,
    input  wire [8:0]  npc_y4, npc_y5, npc_y6, npc_y7,
    input  wire [7:0]  npc_alive,
    input  wire [7:0]  smith_chasing,
    output reg         use_ammo,
    output reg         use_charge,
    output reg         use_emp,
    output reg  [7:0]  smith_kill_mask,
    output reg  [7:0]  smith_stun_mask,
    output reg         replicate_en,
    output reg  [2:0]  replicate_npc_idx,
    output wire [9:0]  bullet_x0, bullet_x1, bullet_x2, bullet_x3,
    output wire [8:0]  bullet_y0, bullet_y1, bullet_y2, bullet_y3,
    output wire [1:0]  bullet_dir0, bullet_dir1, bullet_dir2, bullet_dir3,
    output reg  [3:0]  bullet_active,
    output wire [9:0]  bomb_x0, bomb_x1, bomb_x2, bomb_x3,
    output wire [8:0]  bomb_y0, bomb_y1, bomb_y2, bomb_y3,
    output wire [7:0]  bomb_timer0, bomb_timer1, bomb_timer2, bomb_timer3,
    output reg  [3:0]  bomb_active,
    output reg         destroy_en,
    output reg  [4:0]  destroy_tx,
    output reg  [3:0]  destroy_ty,
    output reg  [8:0]  emp_visual,
    input  wire        start_level
);

    localparam [9:0] BULLET_SPEED = 10'd8;
    localparam [9:0] SMITH_W = 10'd16;
    localparam [8:0] SMITH_H = 9'd20;
    localparam [9:0] NPC_W = 10'd15;
    localparam [8:0] NPC_H = 9'd19;

    reg [9:0] bullet_x [0:3];
    reg [8:0] bullet_y [0:3];
    reg [1:0] bullet_dir [0:3];
    reg [9:0] bomb_x;
    reg [8:0] bomb_y;
    reg [7:0] bomb_timer;
    reg replication_used;
    reg [3:0] shoot_cooldown;
    reg [3:0] bomb_cooldown;
    reg [2:0] replicate_scan_smith;
    reg [2:0] replicate_scan_npc;

    // Local arrays make collision loops readable while keeping module ports
    // flattened for tool compatibility.
    wire [9:0] sx [0:7];
    wire [8:0] sy [0:7];
    wire [9:0] nx [0:7];
    wire [8:0] ny [0:7];
    assign sx[0]=smith_x0; assign sx[1]=smith_x1; assign sx[2]=smith_x2; assign sx[3]=smith_x3;
    assign sx[4]=smith_x4; assign sx[5]=smith_x5; assign sx[6]=smith_x6; assign sx[7]=smith_x7;
    assign sy[0]=smith_y0; assign sy[1]=smith_y1; assign sy[2]=smith_y2; assign sy[3]=smith_y3;
    assign sy[4]=smith_y4; assign sy[5]=smith_y5; assign sy[6]=smith_y6; assign sy[7]=smith_y7;
    assign nx[0]=npc_x0; assign nx[1]=npc_x1; assign nx[2]=npc_x2; assign nx[3]=npc_x3;
    assign nx[4]=npc_x4; assign nx[5]=npc_x5; assign nx[6]=npc_x6; assign nx[7]=npc_x7;
    assign ny[0]=npc_y0; assign ny[1]=npc_y1; assign ny[2]=npc_y2; assign ny[3]=npc_y3;
    assign ny[4]=npc_y4; assign ny[5]=npc_y5; assign ny[6]=npc_y6; assign ny[7]=npc_y7;

    assign bullet_x0=bullet_x[0]; assign bullet_x1=bullet_x[1]; assign bullet_x2=bullet_x[2]; assign bullet_x3=bullet_x[3];
    assign bullet_y0=bullet_y[0]; assign bullet_y1=bullet_y[1]; assign bullet_y2=bullet_y[2]; assign bullet_y3=bullet_y[3];
    assign bullet_dir0=bullet_dir[0]; assign bullet_dir1=bullet_dir[1]; assign bullet_dir2=bullet_dir[2]; assign bullet_dir3=bullet_dir[3];
    assign bomb_x0=bomb_x; assign bomb_x1=10'd0; assign bomb_x2=10'd0; assign bomb_x3=10'd0;
    assign bomb_y0=bomb_y; assign bomb_y1=9'd0; assign bomb_y2=9'd0; assign bomb_y3=9'd0;
    assign bomb_timer0=bomb_timer; assign bomb_timer1=8'd0; assign bomb_timer2=8'd0; assign bomb_timer3=8'd0;

    integer i, j;
    reg [10:0] dist_x;
    reg [10:0] dist_y;
    always @(posedge clk) begin
        if (reset || start_level) begin
            for (i = 0; i < 4; i = i + 1) begin
                bullet_x[i] <= 10'd0;
                bullet_y[i] <= 9'd0;
                bullet_dir[i] <= 2'd0;
            end
            bomb_x <= 10'd0;
            bomb_y <= 9'd0;
            bomb_timer <= 8'd0;
            bullet_active <= 4'd0;
            bomb_active <= 4'd0;
            use_ammo <= 1'b0;
            use_charge <= 1'b0;
            use_emp <= 1'b0;
            smith_kill_mask <= 8'd0;
            smith_stun_mask <= 8'd0;
            replicate_en <= 1'b0;
            replicate_npc_idx <= 3'd0;
            destroy_en <= 1'b0;
            destroy_tx <= 5'd0;
            destroy_ty <= 4'd0;
            emp_visual <= 9'd0;
            shoot_cooldown <= 4'd0;
            bomb_cooldown <= 4'd0;
            replication_used <= 1'b0;
            replicate_scan_smith <= 3'd0;
            replicate_scan_npc <= 3'd0;
        end else begin
            use_ammo <= 1'b0;
            use_charge <= 1'b0;
            use_emp <= 1'b0;
            smith_kill_mask <= 8'd0;
            smith_stun_mask <= 8'd0;
            replicate_en <= 1'b0;
            destroy_en <= 1'b0;

            if (frame_tick && shoot_cooldown != 4'd0) begin
                shoot_cooldown <= shoot_cooldown - 4'd1;
            end
            if (frame_tick && bomb_cooldown != 4'd0) begin
                bomb_cooldown <= bomb_cooldown - 4'd1;
            end

            // Shooting uses up to two active bullet slots and emits use_ammo
            // only when a bullet is successfully spawned.
            if (shoot_pulse && playing && ammo != 6'd0 && shoot_cooldown == 4'd0) begin
                if (!bullet_active[0]) begin
                    bullet_x[0] <= neo_x + 10'd8;
                    bullet_y[0] <= neo_y + 9'd10;
                    bullet_dir[0] <= neo_dir;
                    bullet_active[0] <= 1'b1;
                    use_ammo <= 1'b1;
                    shoot_cooldown <= bullet_time_active ? 4'd3 : 4'd6;
                end else if (!bullet_active[1]) begin
                    bullet_x[1] <= neo_x + 10'd8;
                    bullet_y[1] <= neo_y + 9'd10;
                    bullet_dir[1] <= neo_dir;
                    bullet_active[1] <= 1'b1;
                    use_ammo <= 1'b1;
                    shoot_cooldown <= bullet_time_active ? 4'd3 : 4'd6;
                end
            end

            // Bomb placement is offset in Neo's facing direction.  The bomb
            // later destroys one map tile and damages nearby Smiths.
            if (bomb_pulse && playing && charges != 3'd0 && bomb_cooldown == 4'd0 && !bomb_active[0]) begin
                case (neo_dir)
                    2'd0: begin bomb_x <= neo_x; bomb_y <= (neo_y > 9'd24) ? neo_y - 9'd24 : 9'd0; end
                    2'd1: begin bomb_x <= (neo_x < 10'd600) ? neo_x + 10'd24 : 10'd624; bomb_y <= neo_y; end
                    2'd2: begin bomb_x <= neo_x; bomb_y <= (neo_y < 9'd448) ? neo_y + 9'd24 : 9'd464; end
                    default: begin bomb_x <= (neo_x > 10'd24) ? neo_x - 10'd24 : 10'd0; bomb_y <= neo_y; end
                endcase
                bomb_timer <= 8'd72;
                bomb_active[0] <= 1'b1;
                use_charge <= 1'b1;
                bomb_cooldown <= 4'd8;
            end

            // EMP applies a Manhattan-distance stun mask around Neo.
            if (emp_pulse && playing && emp_count != 2'd0) begin
                use_emp <= 1'b1;
                emp_visual <= 9'd96;
                for (i = 0; i < 8; i = i + 1) begin
                    if (smith_active[i]) begin
                        dist_x = (sx[i] > neo_x) ? {1'b0, sx[i] - neo_x} : {1'b0, neo_x - sx[i]};
                        dist_y = (sy[i] > neo_y) ? {2'b0, sy[i] - neo_y} : {2'b0, neo_y - sy[i]};
                        if (dist_x + dist_y < 11'd176)
                            smith_stun_mask[i] <= 1'b1;
                    end
                end
            end

            if (frame_tick && playing) begin
                // Projectiles and timed effects advance at the video frame rate.
                if (emp_visual != 9'd0)
                    emp_visual <= emp_visual - 9'd1;

                for (i = 0; i < 2; i = i + 1) begin
                    if (bullet_active[i]) begin
                        case (bullet_dir[i])
                            2'd0: bullet_y[i] <= bullet_y[i] - BULLET_SPEED[8:0];
                            2'd1: bullet_x[i] <= bullet_x[i] + BULLET_SPEED;
                            2'd2: bullet_y[i] <= bullet_y[i] + BULLET_SPEED[8:0];
                            default: bullet_x[i] <= bullet_x[i] - BULLET_SPEED;
                        endcase

                        if (bullet_x[i] < 10'd4 || bullet_x[i] > 10'd632 ||
                            bullet_y[i] < 9'd4 || bullet_y[i] > 9'd472) begin
                            bullet_active[i] <= 1'b0;
                        end

                        for (j = 0; j < 8; j = j + 1) begin
                            if (smith_active[j] &&
                                bullet_x[i] + 10'd6 > sx[j] && bullet_x[i] < sx[j] + SMITH_W &&
                                {1'b0, bullet_y[i]} + 10'd6 > {1'b0, sy[j]} &&
                                {1'b0, bullet_y[i]} < {1'b0, sy[j]} + {1'b0, SMITH_H}) begin
                                smith_kill_mask[j] <= 1'b1;
                                bullet_active[i] <= 1'b0;
                            end
                        end
                    end
                end

                if (bomb_active[0]) begin
                    if (bomb_timer == 8'd1) begin
                        bomb_active[0] <= 1'b0;
                        destroy_en <= 1'b1;
                        destroy_tx <= bomb_x[9:5];
                        destroy_ty <= bomb_y[8:5];
                        for (j = 0; j < 8; j = j + 1) begin
                            if (smith_active[j]) begin
                                dist_x = (sx[j] > bomb_x) ? {1'b0, sx[j] - bomb_x} : {1'b0, bomb_x - sx[j]};
                                dist_y = (sy[j] > bomb_y) ? {2'b0, sy[j] - bomb_y} : {2'b0, bomb_y - sy[j]};
                                if (dist_x + dist_y < 11'd64)
                                    smith_kill_mask[j] <= 1'b1;
                            end
                        end
                    end else begin
                        bomb_timer <= bomb_timer - 8'd1;
                    end
                end

                // Scan one Smith/NPC pair per frame for replication.  This keeps
                // the nested overlap search out of a single large combinational
                // block.
                if (!replication_used && smith_active[replicate_scan_smith] && npc_alive[replicate_scan_npc]) begin
                    if (sx[replicate_scan_smith] + SMITH_W > nx[replicate_scan_npc] &&
                        sx[replicate_scan_smith] < nx[replicate_scan_npc] + NPC_W &&
                        {1'b0, sy[replicate_scan_smith]} + {1'b0, SMITH_H} > {1'b0, ny[replicate_scan_npc]} &&
                        {1'b0, sy[replicate_scan_smith]} < {1'b0, ny[replicate_scan_npc]} + {1'b0, NPC_H}) begin
                        replicate_en <= 1'b1;
                        replicate_npc_idx <= replicate_scan_npc;
                        replication_used <= 1'b1;
                    end
                end

                if (replicate_scan_npc == 3'd7) begin
                    replicate_scan_npc <= 3'd0;
                    replicate_scan_smith <= replicate_scan_smith + 3'd1;
                end else begin
                    replicate_scan_npc <= replicate_scan_npc + 3'd1;
                end
            end
        end
    end

endmodule
