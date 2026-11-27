`timescale 1ns / 1ps

package ahb_to_apb_package;
	
	typedef enum bit [1:0] {IDLE = 2'b00, BUSY, NONSEQ, SEQ} htrans_e; 
	
	class transaction;
	
		// ---------------- address map  ----------------
		localparam bit [31:0] SLV0_LO = 32'h0000_0000, SLV0_HI = 32'h0000_00FF;
		localparam bit [31:0] SLV1_LO = 32'h0000_0100, SLV1_HI = 32'h0000_01FF;
		localparam bit [31:0] SLV2_LO = 32'h0000_0200, SLV2_HI = 32'h0000_02FF;
  
		rand htrans_e   HTRANS;
		rand bit        HWRITE;
		rand bit        HREADYIN;
		rand bit [31:0] HADDR;
		rand bit [31:0] HWDATA;
		
		
		bit [31:0] PRDATA;
		
		bit [31:0] HRDATA;
		bit        HREADYOUT;
		bit [1:0]  HRESP;
		
		bit [31:0] PADDR;
		bit [31:0] PWDATA;
		bit        PWRITE;
		bit [2:0]  PSEL;
		bit        PENABLE;
		
		// Control Knob
		// 0 -> mixed signal values ( valid + invalid addresses, IDLE/BUSY Trans, HREADY is 0)
		// 1 -> Valid address, NON-seq, seq Trans, HREADY is high
		bit valid_only = 1'b0;
		
		// Constraints
		
		// Read & Write with 50%
		constraint c_rw {
			HWRITE dist { 1:= 50, 0:=50};
		}
		
		constraint c_htrans {
			if(valid_only) { HTRANS inside {NONSEQ, SEQ}; }
			else { HTRANS dist {IDLE := 10, BUSY := 5, NONSEQ := 55, SEQ := 30}; }
		}
		
		/* constraint c_hready_in {
			if(valid_only) { HREADYIN == 1'b1; }
			else { HREADYIN dist {1 := 80, 0 := 20}; }
		} */
		
		constraint c_hready_in { HREADYIN == 1'b1; }
		
		constraint c_haddr_aligned {
			HADDR[1:0] == 2'b00;
		}
		
		constraint c_haddr_range {
			if(valid_only) { HADDR inside {[SLV0_LO:SLV0_HI], [SLV1_LO:SLV1_HI], [SLV2_LO:SLV2_HI]};}
			else { HADDR dist {
					[SLV0_LO:SLV0_HI] :/ 30,
					[SLV1_LO:SLV1_HI] :/ 30,
					[SLV2_LO:SLV2_HI] :/ 30,   
					[32'h0000_0000 : 32'hFFFF_FFFF] :/ 10    // rest addresses end
				}; 
			}
		}
		
		constraint c_hwdata {
			(HWRITE == 1'b0) -> (HWDATA == 32'd0);
		}
		
		constraint c_hwdata_1{
		  HWDATA inside {[1024:2048]};
		}
		// Helper Methods
		function transaction copy();
			transaction t = new();
			t.HTRANS    = this.HTRANS;
			t.HWRITE    = this.HWRITE;
			t.HREADYIN  = this.HREADYIN;
			t.HADDR     = this.HADDR;
			t.HWDATA    = this.HWDATA;
			t.PRDATA    = this.PRDATA;
			t.HRDATA    = this.HRDATA;
			t.HREADYOUT = this.HREADYOUT;
			t.HRESP     = this.HRESP;
			t.PADDR     = this.PADDR;
			t.PWDATA    = this.PWDATA;
			t.PWRITE    = this.PWRITE;
			t.PSEL      = this.PSEL;
			t.PENABLE   = this.PENABLE;
			return t;
		endfunction
		
		function string conv2str(input string msg);
			return $sformatf({"[%0t] || [%s] : HTRANS=%s HWRITE=%0b HREADYIN=%0b HADDR=0x%04h ",
                    "HWDATA=%0d PRDATA=%0d HRDATA=%0d HREADYOUT=%0b HRESP=%02b ",
                    "PADDR=0x%04h PWDATA=%0d PWRITE=%0b PSEL=%03b PENABLE=%0b"},
                   $time, msg, HTRANS.name(), HWRITE, HREADYIN, HADDR,
                   HWDATA, PRDATA, HRDATA, HREADYOUT, HRESP,
                   PADDR, PWDATA, PWRITE, PSEL, PENABLE);
		endfunction
		
		function void display(input string msg);
			$display("%s", conv2str(msg));
		endfunction
	endclass
	
	
	class generator;
		transaction t;
		mailbox #(transaction) gen2drv;
		
		function new(mailbox #(transaction) gen2drv);
			this.gen2drv = gen2drv;
			t = new();
		endfunction
		
		task run(input int cycles = 5);
			repeat(cycles) begin
				assert(t.randomize()) else $error("[%0t]: Randomization Failed..!", $time);
				t.display("GEN");
				gen2drv.put(t.copy());
			end
		endtask
	endclass
	
	class driver;
		transaction t_addr, t_data;
		mailbox #(transaction) gen2drv;
		virtual ahb_to_apb_interface.mod_ahb_drv vif;
		int sent = 0;
		event e1;
		
		function new(mailbox #(transaction) gen2drv, virtual ahb_to_apb_interface.mod_ahb_drv vif);
			this.gen2drv = gen2drv;
			this.vif     = vif;
		endfunction
		
		task drive_idle();
			vif.cb_ahb_drv.HTRANS <= IDLE;
			vif.cb_ahb_drv.HWRITE   <= 0;
			// vif.cb_ahb_drv.HREADYIN <= 1;
			vif.cb_ahb_drv.HADDR    <= 0;
			vif.cb_ahb_drv.HWDATA   <= 0;
		endtask
		
		task run(input int cycles = 5);
			sent = 0;
			drive_idle();
			wait(vif.HRESETn == 1'b1);
			@(vif.cb_ahb_drv);  
			t_data = null;
			
			repeat(cycles + 1) begin
				
				if(sent < cycles) begin
					gen2drv.get(t_addr);
					t_addr.display("DRV");
					sent++;
				end
				else
					t_addr = null;
				
				if(t_addr != null) begin
					vif.cb_ahb_drv.HTRANS   <= t_addr.HTRANS;
					vif.cb_ahb_drv.HWRITE   <= t_addr.HWRITE;
					// vif.cb_ahb_drv.HREADYIN <= t_addr.HREADYIN;
					vif.cb_ahb_drv.HADDR    <= t_addr.HADDR;
				end
				else begin
					vif.cb_ahb_drv.HTRANS     <= IDLE;
					// vif.cb_ahb_drv.HREADYIN   <= 1'b1;
				end
				
				if(t_data != null) begin
					vif.cb_ahb_drv.HWDATA     <= t_data.HWDATA;
				end
				
				do @(vif.cb_ahb_drv); while (!vif.cb_ahb_drv.HREADYOUT);
				t_data = t_addr;
			end
			drive_idle();
			->e1;
		endtask
	endclass
	
	class monitor_ahb;
		transaction t_addr;
		mailbox #(transaction) mon2scb_ahb;
		virtual ahb_to_apb_interface.mod_ahb_mon vif;
			
		function new(mailbox #(transaction) mon2scb_ahb, virtual ahb_to_apb_interface.mod_ahb_mon vif);
			this.mon2scb_ahb = mon2scb_ahb;
			this.vif         = vif;
		endfunction
		
		task run();
			t_addr = null;
			forever begin
				@(vif.cb_ahb_mon);
				if(vif.HRESETn) begin
					// 1) data phase of the previous transfer finishes at this edge
					if(vif.cb_ahb_mon.HREADYOUT) begin
						if(t_addr != null) begin
							t_addr.HWDATA    = vif.cb_ahb_mon.HWDATA;
							t_addr.HRDATA    = vif.cb_ahb_mon.HRDATA;
							t_addr.HREADYOUT = 1'b1; //vif.cb_ahb_mon.HREADYOUT;
							t_addr.HRESP     = vif.cb_ahb_mon.HRESP;
							
							t_addr.display("MON_AHB");
							mon2scb_ahb.put(t_addr);
							t_addr = null;
						end
						// 2) a new transfer's address phase is accepted at this edge
						if(vif.cb_ahb_mon.HTRANS inside {NONSEQ, SEQ}) begin
							t_addr          = new();
							t_addr.HTRANS   = htrans_e'(vif.cb_ahb_mon.HTRANS);
							t_addr.HWRITE   = vif.cb_ahb_mon.HWRITE;
							t_addr.HADDR    = vif.cb_ahb_mon.HADDR;
							t_addr.HREADYIN = vif.cb_ahb_mon.HREADYIN;
							// t_addr.display("MON_AHB");
						end
					end
				end
				else begin
					t_addr = null;
				end
			end
			
		endtask
	endclass
	
	class monitor_apb;
		transaction t;
		mailbox #(transaction) mon2scb_apb;
		virtual ahb_to_apb_interface.mod_apb_mon vif;
		
		function new(mailbox #(transaction) mon2scb_apb, virtual ahb_to_apb_interface.mod_apb_mon vif);
			this.mon2scb_apb = mon2scb_apb;
			this.vif         = vif;
		endfunction
		
		task run();
			forever begin
				@(vif.cb_apb_mon);
				if(vif.HRESETn && vif.cb_apb_mon.PSEL != 3'b000 && vif.cb_apb_mon.PENABLE) begin
					t          = new();
					t.PRDATA   = vif.cb_apb_mon.PRDATA;
					t.PADDR    = vif.cb_apb_mon.PADDR;
					t.PWDATA   = vif.cb_apb_mon.PWDATA;
					t.PWRITE   = vif.cb_apb_mon.PWRITE;
					t.PSEL     = vif.cb_apb_mon.PSEL;
					t.PENABLE  = vif.cb_apb_mon.PENABLE;
					
					t.display("MON_APB");
					mon2scb_apb.put(t);
				end
			end
		endtask
	endclass
	
	class scoreboard;
	    localparam bit [31:0] SLV0_LO = 32'h0000_0000, SLV0_HI = 32'h0000_00FF;
		localparam bit [31:0] SLV1_LO = 32'h0000_0100, SLV1_HI = 32'h0000_01FF;
		localparam bit [31:0] SLV2_LO = 32'h0000_0200, SLV2_HI = 32'h0000_02FF;
		
		transaction t_ahb, t_apb;
		mailbox #(transaction) mon2scb_apb;
		mailbox #(transaction) mon2scb_ahb;
		
		int unsigned timeout_ns = 1000; 
		int total = 0, ignored = 0, pass_cnt = 0, fail_cnt = 0;
		
		bit [31:0] ref_mem [bit [31:0]]; // associative array as memory
		
		function new(mailbox #(transaction) mon2scb_apb, mailbox #(transaction) mon2scb_ahb);
			this.mon2scb_apb = mon2scb_apb;
			this.mon2scb_ahb = mon2scb_ahb;
		endfunction
		
		function bit check(input string name, input bit [31:0] got, input bit [31:0] expected);
			if(got != expected) begin
				$error("[%0t] SCB: \"%s\" mismatch, expected = 0X%04h, got = 0X%04h", $time, name,  expected, got);
				return 1'b0;
			end
			return 1'b1;
		endfunction
		
		function bit is_valid(transaction t);
			return t.HREADYIN && (t.HTRANS == NONSEQ || t.HTRANS == SEQ) && (t.HADDR inside {[SLV0_LO:SLV0_HI], [SLV1_LO:SLV1_HI], [SLV2_LO:SLV2_HI]});
		endfunction
		
		function bit [2:0] decode_psel(input bit [31:0] addr);
			if     (addr inside {[SLV0_LO:SLV0_HI]}) return 3'b001;
			else if(addr inside {[SLV1_LO:SLV1_HI]}) return 3'b010;
			else if(addr inside {[SLV2_LO:SLV2_HI]}) return 3'b100;
			else return 3'b000;
		endfunction
		
		// compare one AHB request against the APB transfer it produced (1 = pass)
		function bit check_transfer(transaction t_ahb, transaction t_apb);
			bit ok = 1'b1;
			
			ok &= check("PADDR", t_apb.PADDR, t_ahb.HADDR);
			
			ok &= check("PWRITE", t_apb.PWRITE, t_ahb.HWRITE);
			
			ok &= check("PSEL", t_apb.PSEL, decode_psel(t_ahb.HADDR));
			
			ok &= check("PENABLE", t_apb.PENABLE, 1'b1);
			
			if(t_ahb.HWRITE) begin
				ok &= check("PWDATA", t_apb.PWDATA, t_ahb.HWDATA);
			end
			else begin
				if(ref_mem.exists(t_ahb.HADDR)) begin
					ok &= check("PRDATA", t_apb.PRDATA, ref_mem[t_ahb.HADDR]);
				end
				ok &= check("HRDATA vs PRDATA", t_ahb.HRDATA, t_apb.PRDATA);
			end
			
			return ok;
			
		endfunction
		
		task run();
			forever begin
				mon2scb_ahb.get(t_ahb);
				total++;
				
				// check 1: AHB response must be OKAY
				if(!check("HRESP", t_ahb.HRESP, 2'b00))
					fail_cnt++;
				
				// check 2: invalid request -> no APB transfer expected,
				if(!is_valid(t_ahb)) begin
					ignored++;
					continue;
				end
				
				// reference model: a valid write update the model memory
				if(t_ahb.HWRITE) begin
					ref_mem[t_ahb.HADDR] = t_ahb.HWDATA;
				end
				
				// check 3: APB transfer should show update
				fork
					begin
						wait(mon2scb_apb.num() > 0);
					end
					begin
						#timeout_ns;
					end
				join_any 
				disable fork;
				
				if(mon2scb_apb.num() == 0) begin
					fail_cnt++;
					$error("[%0t] SCB: no APB transfer for valid request HADDR=0x%04h", $time, t_ahb.HADDR);
					continue;
				end
				
				// check 4: all fields of the APB transfer
				mon2scb_apb.get(t_apb);
				if(check_transfer(t_ahb, t_apb)) begin
					pass_cnt++;
					$display("[%0t] [SCB] PASS: %s, addr = 0X%04h", $time, t_ahb.HWRITE? "WR" : "RD", t_ahb.HADDR);
				end
				else begin
					fail_cnt++;
					t_ahb.display("SCB_AHB");
					t_apb.display("SCB_APB");
					$display("--------------------------------------------------");
				end
				
			end
		endtask
		
		function void report();
			$display("============== SCOREBOARD REPORT ==============");
			$display(" AHB transfers : %0d (ignored as invalid: %0d)", total, ignored);
			$display(" Passed / Failed : %0d / %0d", pass_cnt, fail_cnt);
			if (fail_cnt == 0) $display(" RESULT : TEST PASSED");
			else               $display(" RESULT : TEST FAILED");
			$display("===============================================");
		endfunction
	endclass
	
	class environment;
		mailbox #(transaction) gen2drv;
		mailbox #(transaction) mon2scb_apb;
		mailbox #(transaction) mon2scb_ahb;
		
		generator   gen;
		driver      drv;
		monitor_ahb mon_ahb;
		monitor_apb mon_apb;
		scoreboard  scb;
		event e1;
		
		function new(virtual ahb_to_apb_interface vif);
			gen2drv     = new();
			mon2scb_apb = new();
			mon2scb_ahb = new();
			
			gen     = new(gen2drv);
			drv     = new(gen2drv, vif.mod_ahb_drv);
			mon_ahb = new(mon2scb_ahb, vif.mod_ahb_mon);
			mon_apb = new(mon2scb_apb, vif.mod_apb_mon);
			scb     = new(mon2scb_apb, mon2scb_ahb);
			drv.e1  = e1;
		endfunction
		
		task run(input int cycles = 5);
			fork
				gen.run(cycles);
				drv.run(cycles);
				mon_ahb.run();
				mon_apb.run();
				scb.run();
			join_any
			@(e1);
			#50;
			scb.report();
			#20;
			$finish;
		endtask
	endclass
	
	class test;
		environment env;
		
		function new(virtual ahb_to_apb_interface vif);
			env = new(vif);
		endfunction
		
		task run(input int cycles = 5);
			env.run(cycles);
		endtask
	endclass
endpackage
