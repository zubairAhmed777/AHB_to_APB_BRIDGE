`timescale 1ns / 1ps

`define TEST_4

module tb_ahb_to_apb_bridge_top;
	bit         HCLK;
	bit         HRESETn;
	bit [1:0]   HTRANS;
	bit         HWRITE;
	bit [31:0]  HADDR;
	bit [31:0]  HWDATA;
	
	wire        HREADYOUT;
	wire        HREADYIN = HREADYOUT;
	wire [31:0] HRDATA;
	wire [1:0]  HRESP;
	
	wire [31:0] PADDR;
	wire [31:0] PWDATA;
	wire [31:0] PRDATA;
	wire [2:0]  PSEL;
	wire        PENABLE;
	wire        PWRITE;
	
	ahb_apb_bridge u_ahb_apb_bridge(
		.HCLK(HCLK),
		.HRESETn(HRESETn),
		.HTRANS(HTRANS),
		.HWRITE(HWRITE),
		.HREADYIN(HREADYIN),
		.HADDR(HADDR),
		.HWDATA(HWDATA),
		.HRDATA(HRDATA),
		.HREADYOUT(HREADYOUT),
		.HRESP(HRESP),
		.PRDATA(PRDATA),
		.PADDR(PADDR),
		.PWDATA(PWDATA),
		.PWRITE(PWRITE),
		.PSEL(PSEL),
		.PENABLE(PENABLE)
	);
	
	always #5 HCLK = ~HCLK;
	
	// APB slaves
	reg [31:0] mem [0:1023];
	wire [1:0] sidx = PSEL[0]?2'd0:PSEL[1]?2'd1:2'd2;
	wire [9:0] midx = {sidx, PADDR[9:2]};
	
	assign PRDATA = mem[midx];
	
	always @(posedge HCLK) begin
		if(PSEL != 3'b000 && PENABLE && PWRITE) begin
			mem[midx] <= PWDATA;
		end
	end
	
	// Reset task
	task reset(input int cycles);
		HRESETn = 1'b0;
		HTRANS  = 2'b00;
		HWRITE  = 1'b0;
		HADDR   = 32'd0;
		HWDATA  = 32'd0;
		repeat(cycles) @(posedge HCLK);
		HRESETn = 1'b1;
	endtask
	
	// ahb master tasks
	// single write: address phase, then data phase, then wait for APB to finish
	task ahb_write(input [31:0] addr, input [31:0] data);
		// Address Phase
		@(negedge HCLK);
		HTRANS = 2'b10;
		HWRITE = 1'b1;
		HADDR  = addr;
		// Data Phase
		@(negedge HCLK);
		HTRANS = 2'b00;
		HADDR  = 32'b0;
		HWDATA = data;
		// Wait for APB to finish
		repeat(4) @(posedge HCLK);
	endtask
	
	reg [31:0] rd = 32'd0;
	// single read: address phase, then wait until HREADYOUT=1 and take HRDATA
	task ahb_read(input [31:0] addr, output [31:0] data);
		// Address phase
		@(negedge HCLK);
		HTRANS = 2'b10;
		HWRITE = 1'b0;
		HADDR  = addr;
		// wait for HREADYOUT = 1
		@(negedge HCLK);
		HTRANS = 2'b00;
		while(HREADYOUT != 1'b1) @(posedge HCLK);
		data = HRDATA;
	endtask
	
	// two back-to-back (pipelined) writes
	task ahb_write2(input [31:0] a1, input [31:0] d1, input [31:0] a2, input [31:0] d2);
		@(negedge HCLK);
		HWRITE = 1'b1;
		HTRANS = 2'b10;
		HADDR  = a1;     // Address 1
		@(negedge HCLK);
		HWRITE = 1'b1;
		HTRANS = 2'b10;
		HADDR  = a2;   // Address 2
		HWDATA = d1;   // Data 1
		@(negedge HCLK);
		HTRANS = 2'b00;
		HWDATA = d2;   // Data 2
		HWRITE = 1'b0;
		@(negedge HCLK);
		
		while(HREADYOUT != 1'b1) @(posedge HCLK);
		repeat(2) @(posedge HCLK);
	endtask
	
	// write immediately followed by a read (no idle cycle between them)
	task ahb_write_read(input [31:0] wa, input [31:0] wd, input [31:0] ra, output [31:0] rdata);
		@(negedge HCLK);
		HWRITE = 1'b1;
		HTRANS = 2'b10;
		HADDR  = wa;     // Write Address 1
		@(negedge HCLK);
		HWRITE = 1'b0;
		HTRANS = 2'b10;
		HADDR  = ra;   // Read Address 2
		HWDATA = wd;   // Data 1
		@(negedge HCLK);
		HTRANS = 2'b00;
		@(negedge HCLK);
		while(HREADYOUT != 1'b1) @(posedge HCLK);
		rdata = HRDATA;
		repeat(2) @(posedge HCLK);
	endtask
	
	int errors = 0;
	int checks = 0;
	task check(input string msg = "", input [31:0] exp, got);
		checks = checks + 1'b1;
		if(exp == got)
			$display("[%0t]: Pass - %0s, got = %0h", $time, msg, got);
		else begin
			errors = errors + 1'b1;
			$display("[%0t]: failed - %0s, got = %0h, exp = %0h", $time, msg, got, exp);
		end
	endtask
	
	initial begin
		reset(3);
		`ifdef TEST_1
			ahb_write(32'h8000_0010, 32'h1111_1111);
			ahb_read(32'h8000_0010, rd);
			// #1;
			// check("W-R slave0", 32'h1111_1111, rd);
			// 3. Read then write then read (R-W-R)
			// ahb_read (32'h8000_0010, rd);   
			check("R-W-R  first read", rd, 32'h1111_1111);
			/* Uncomment 
			ahb_write(32'h8000_0010, 32'hAAAA_AAAA);
			ahb_read (32'h8000_0010, rd);   
			check("R-W-R  after write", rd, 32'hAAAA_AAAA);
			*/
		`endif
		`ifdef TEST_2
			// 2. Each of the 3 APB slave ranges
			ahb_write(32'h8400_0020, 32'h2222_2222);
			ahb_write(32'h8800_0030, 32'h3333_3333);
			#1;
			ahb_read (32'h8400_0020, rd);
			check("W-W-R slave1", rd, 32'h2222_2222);
			ahb_read (32'h8800_0030, rd);   
			check("R - slave2", rd, 32'h3333_3333);
			// 4. Read-read (R-R)
			/*
			ahb_read (32'h8400_0020, rd);   
			check("R-R    first", rd, 32'h2222_2222);
			ahb_read (32'h8800_0030, rd);   
			check("R-R    second", rd, 32'h3333_3333); 
			*/
		`endif
		
		`ifdef TEST_3
			// 5. Back-to-back (pipelined) write-write, then read both
			ahb_write2(32'h8000_0010, 32'h4444_4444, 32'h8000_0014, 32'h5555_5555);
			ahb_read (32'h8000_0010, rd);   
			check("W-W    first", 32'h4444_4444, rd);
			ahb_read (32'h8000_0014, rd);   
			check("W-W    second", 32'h5555_5555, rd);
		`endif
		
		`ifdef TEST_4
			ahb_write_read(32'h8000_0010, 32'h6666_6666, 32'h8000_0010, rd);
			check("W-R pipelined", rd, 32'h6666_6666);
		`endif
		
		`ifdef TEST_5
		      // Develop WWRR sequence.
		`endif
		
		$display("----------------------------------------");
		$display("[%0t]: %0d checks, %0d errors", $time, checks, errors);
		if (errors == 0) $display("ALL TESTS PASSED");
		else             $display("SOME TESTS FAILED");
	end
	
	initial begin
		for(int i=0; i<1024; i++) begin
			mem[i] = 32'd0;
		end
		#200;
		$stop;
	end
endmodule
