`timescale 1ns / 1ps

interface ahb_to_apb_interface(input wire HCLK, input wire HRESETn);
	logic [1:0]  HTRANS;
	logic        HWRITE;
	logic        HREADYIN;
	logic [31:0] HADDR;
	logic [31:0] HWDATA;
	logic [31:0] HRDATA;
	logic        HREADYOUT;
	logic [1:0]  HRESP;
	
	logic [31:0] PRDATA;
	logic [31:0] PADDR;
	logic [31:0] PWDATA;
	logic        PWRITE;
	logic [2:0]  PSEL;
	logic        PENABLE;
	
	assign HREADYIN = HREADYOUT;
	
	clocking cb_ahb_drv @(posedge HCLK);
		default input #1step output #1ns;
		output HTRANS;
		output HWRITE;
		// output HREADYIN;
		output HADDR;
		output HWDATA;
		input  HRDATA;
		input  HREADYOUT;
		input  HRESP;
		// assign HREADYIN = HREADYOUT;
	endclocking
	
	clocking cb_ahb_mon @(posedge HCLK);
		default input #1step output #1ns;
		input HTRANS;
		input HWRITE;
		input HREADYIN;
		input HADDR;
		input HWDATA;
		input HRDATA;
		input HREADYOUT;
		input HRESP;
	endclocking
	
	clocking cb_apb_mon @(posedge HCLK);
		input  PRDATA;
		input  PADDR;
		input  PWDATA;
		input  PWRITE;
		input  PSEL;
		input  PENABLE;
	endclocking
	
	modport mod_ahb_drv(clocking cb_ahb_drv, input HRESETn);
	modport mod_ahb_mon(clocking cb_ahb_mon, input HRESETn);
	
	modport mod_apb_mon(clocking cb_apb_mon, input HRESETn);
endinterface
