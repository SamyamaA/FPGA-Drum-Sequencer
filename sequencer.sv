module sequencer (CLOCK_50, reset, advance, STEP_TICKS, kickPattern, hatPattern, snarePattern, kickTrig, snareTrig, hatTrig);
	input logic CLOCK_50, reset, advance;
	input logic [13:0] STEP_TICKS;
	input logic [7:0] kickPattern;
	input logic [7:0] snarePattern;
	input logic [7:0] hatPattern;
	output logic kickTrig, snareTrig, hatTrig;
	
	logic [13:0] on;
	logic step_tick;

	always_ff @(posedge CLOCK_50) begin
		if (reset) begin 
			on <= 14'd0;
			step_tick <= 1'b0;
		end
		
		else if (advance) begin
			if (on == STEP_TICKS - 1) begin
            on <= 14'd0;
            step_tick <= 1'b1;
        end
        
		  else begin
            on <= on + 14'd1;
            step_tick <= 1'b0;
        end
		end
		
		else begin
			step_tick <= 1'b0;
		end
	end 

	
	logic [2:0] playhead;
	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			playhead <= 3'd0;
		end
		
		else if (step_tick) begin
			playhead <= playhead + 3'd1;
		end	
	end
	
	logic [2:0] next_step;
	assign next_step = playhead + 3'd1;
	
	assign kickTrig = step_tick & kickPattern[next_step];
	assign snareTrig = step_tick & snarePattern[next_step];
	assign hatTrig = step_tick & hatPattern[next_step];
	
endmodule 


module sequencer_testbench();
	logic CLOCK_50, reset, advance;
	logic [13:0] STEP_TICKS;
	logic [7:0] kickPattern, snarePattern, hatPattern;
	logic kickTrig, snareTrig, hatTrig;

	sequencer dut (.CLOCK_50, .reset, .advance, .STEP_TICKS,
	               .kickPattern, .snarePattern, .hatPattern,
	               .kickTrig, .snareTrig, .hatTrig);

	parameter CLOCK_PERIOD = 20;
	initial begin
		CLOCK_50 <= 0;
		forever #(CLOCK_PERIOD/2) CLOCK_50 <= ~CLOCK_50;
	end

	initial begin
		advance <= 0;
		forever begin
			@(posedge CLOCK_50);
			advance <= 1'b1;
			@(posedge CLOCK_50);
			advance <= 1'b0;
		end
	end

	initial begin
		//stall steps to go fast in model sim
		STEP_TICKS <= 14'd3;

		kickPattern  <= 8'b00010001; //kick on steps 0 and 4
		snarePattern <= 8'b00100000; //snare on step 5
		hatPattern   <= 8'b10101010; //hat on odd steps 1,3,5,7

		//reset
		reset <= 1'b1;
		repeat (3) @(posedge CLOCK_50);
		reset <= 1'b0;

		//run long enough to loop through all 8 steps a couple times.
		repeat (80) @(posedge advance);

		$stop;
	end
endmodule
