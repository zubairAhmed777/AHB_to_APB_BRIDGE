`timescale 1ns / 1ps

module ahb_apb_bridge (
    // AHB side
    input             HCLK,
    input             HRESETn,
    input      [1:0]  HTRANS,
    input             HWRITE,
    input             HREADYIN,
    input      [31:0] HADDR,
    input      [31:0] HWDATA,
    output     [31:0] HRDATA,
    output            HREADYOUT,
    output     [1:0]  HRESP,

    // APB side
    input      [31:0] PRDATA,
    output     [31:0] PADDR,
    output     [31:0] PWDATA,
    output            PWRITE,
    output     [2:0]  PSEL,
    output            PENABLE
);

    wire        valid, hwrite_reg;
    wire [2:0]  tempselx, selx_q, selx_q2;
    wire [31:0] haddr_q, haddr_q2, hwdata_q;

    ahb_slave_interface u_ahb_if (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HTRANS(HTRANS), .HREADYIN(HREADYIN),
        .HWRITE(HWRITE), .HADDR(HADDR), .HWDATA(HWDATA),
        .valid(valid), .tempselx(tempselx), .hwrite_reg(hwrite_reg),
        .haddr_q(haddr_q), .haddr_q2(haddr_q2),
        .selx_q(selx_q), .selx_q2(selx_q2),
        .hwdata_q(hwdata_q)
    );

    apb_controller3 u_apb_ctrl (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .valid(valid), .hwrite(HWRITE), .hwrite_reg(hwrite_reg),
        .haddr_q(haddr_q), .haddr_q2(haddr_q2),
        .selx_q(selx_q), .selx_q2(selx_q2),
        .hwdata_q(hwdata_q), .prdata(PRDATA),
        .paddr(PADDR), .pwdata(PWDATA), .pwrite(PWRITE),
        .psel(PSEL), .penable(PENABLE),
        .hready_out(HREADYOUT), .hrdata(HRDATA)
    );

    assign HRESP = 2'b00;   // OKAY

endmodule
