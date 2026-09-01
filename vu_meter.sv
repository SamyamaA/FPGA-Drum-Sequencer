module vu_meter (CLOCK_50, advance, reset, mixed, RedPixels, GrnPixels);
	input logic CLOCK_50, advance, reset;
	input logic signed [23:0] mixed;
	output logic [15:0][15:0] RedPixels;
	output logic [15:0][15:0] GrnPixels;
	
	logic [23:0] absMixed;
	logic [23:0] level;
	localparam logic [23:0] decay = 24'd500;

	always_comb begin
		if (mixed[23]) begin
			absMixed = -mixed;
		end
		else begin
			absMixed = mixed;
		end
	end
	
	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			level <= 24'd0;
		end
		else if (advance) begin
			if (absMixed > level) begin
				level <= absMixed;
			end
			else if (level > decay) begin
				level <= level - decay;
			end
			else begin
				level <= 24'd0;
			end
		end
	end
	
	logic [3:0] height;	
	localparam logic [23:0] fullScale = 24'h600000;
	localparam logic [23:0] step = fullScale / 16; //0x60000

	always_comb begin
		 if (level >= fullScale)
			  height = 4'd15;          
		 else
			  height = level / step;   
	end
	
	integer row;
   always_comb begin
       RedPixels = 256'b0;
       GrnPixels = 256'b0;
       for (row = 0; row < 16; row = row + 1) begin
           if ((15 - row) < height) begin //15 is bottom row
              if (row <= 4) begin //top rows: red (peak)
               RedPixels[row] = 16'hFFFF;
           end
           else if (row <= 10) begin //middle rows: orange (red + green)
               RedPixels[row] = 16'hFFFF;
               GrnPixels[row] = 16'hFFFF;
           end
           else begin //bottom rows: green
               GrnPixels[row] = 16'hFFFF;
           end
          end
      end
   end
	
endmodule



module vu_meter_testbench();
	logic CLOCK_50, advance, reset;
	logic signed [23:0] mixed;
	logic [15:0][15:0] RedPixels, GrnPixels;

	vu_meter dut (.CLOCK_50, .advance, .reset, .mixed, .RedPixels, .GrnPixels);

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
		reset <= 1'b1; mixed <= 24'sd0;
		repeat (3) @(posedge CLOCK_50);
		reset <= 1'b0;

		//loud positive sample -> level should SNAP up
		mixed <= 24'sh600000; //full scale
		repeat (3) @(posedge advance);
		$display("after loud hit: level=%h  height=%0d (expect level~600000, height 15)", dut.level, dut.height);

		//go silent -> level should DECAY slowly, not instantly
		mixed <= 24'sd0;
		repeat (5) @(posedge advance);
		$display("after 5 quiet: level=%h  height=%0d (should be dropping)", dut.level, dut.height);
		repeat (50) @(posedge advance);
		$display("after 55 quiet: level=%h  height=%0d (lower still)", dut.level, dut.height);

		//negative sample -> abs value should still register
		mixed <= -24'sh400000; //loud negative
		repeat (3) @(posedge advance);
		$display("after neg hit: level=%h  height=%0d (abs should make level ~400000)", dut.level, dut.height);

		$stop;
	end
endmodule