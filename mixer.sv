module mixer (kickSound, snareSound, hatSound, mixed_out);
	input logic signed [23:0] kickSound;
	input logic signed [23:0] snareSound;	
	input logic signed [23:0] hatSound;	
	output logic signed [23:0] mixed_out;
	
	localparam logic signed [23:0] MAX =  24'sh7FFFFF; //8388607
	localparam logic signed [23:0] MIN = -24'sh800000; //-8388608
	
	logic signed [24:0] raw_sum;
	
	always_comb begin
		raw_sum = kickSound + snareSound + hatSound;
		if (raw_sum > MAX) begin
			mixed_out = MAX;
		end
		
		else if (raw_sum < MIN) begin
			mixed_out = MIN;
		end
		
		else begin
			mixed_out = raw_sum[23:0];
		end
	end
endmodule


module mixer_testbench();
	logic signed [23:0] kickSound, snareSound, hatSound;
	logic signed [23:0] mixed_out;

	mixer dut (.kickSound, .snareSound, .hatSound, .mixed_out);

	initial begin
		//negative sum no clamp
		kickSound = -24'sh100000; snareSound = -24'sh100000; hatSound = -24'sh080000;
		#10

		//positive overflow with clamp
		kickSound = 24'sh400000; snareSound = 24'sh400000; hatSound = 24'sh400000;
		#10
		
		//the actual volumes
		kickSound = 24'sh200000; snareSound = 24'sh200000; hatSound = 24'sh180000;
		#10
		$stop;
	end
endmodule
			
