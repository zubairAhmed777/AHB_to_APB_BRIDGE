`timescale 1ns / 1ps

import ahb_to_apb_package::*;

module tb_ahb_to_apb_bridge_sv;
	bit HCLK = 1'b0;
	bit HRESETn;
	
	ahb_to_apb_interface vif(HCLK, HRESETn);
	
	always #5 HCLK = ~HCLK;
	
	test tst;
	
	bit [31:0] mem [1024];
	
	ahb_apb_bridge u_ahb_apb_bridge(HCLK, 
									HRESETn, 
									vif.HTRANS, 
									vif.HWRITE, 
									vif.HREADYIN, 
									vif.HADDR,
									vif.HWDATA,
									vif.HRDATA,
									vif.HREADYOUT,
									vif.HRESP,
									vif.PRDATA,
									vif.PADDR,
									vif.PWDATA,
									vif.PWRITE,
									vif.PSEL,
									vif.PENABLE
									);
	
	task reset(input int cycles = 5);
		HRESETn = 1'b0;
		repeat(cycles) @(posedge HCLK);
		@(negedge HCLK);
		HRESETn = 1'b1;
	endtask
	
	// write during the APB access phase
	always @(posedge HCLK) begin
		if(|vif.PSEL && vif.PENABLE && vif.PWRITE)
			mem[vif.PADDR] <= vif.PWDATA;
	end
	
	// Read during access phase
	assign vif.PRDATA = mem[vif.PADDR];
	
	initial begin
		tst = new(vif);
		tst.env.gen.t.valid_only = 1'b1;
		reset(5);
		tst.run(5);
	end
	
	initial begin
		#500;
		$finish;
	end
endmodule
