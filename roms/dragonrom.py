import sys

def main(args):
   print("module rom_"+args[0])
   print("(")
   print("input clk,")
   print("input [12:0] addr,")
   print("output [7:0] dout,")
   print("input cs );")
   print("reg [7:0] q;")
   print("always @(posedge clk) ");
   print("begin ");
   print("case (addr) ");
   with open(args[0],mode="rb") as fp:
       cnt=0
       num=list(fp.read())
       for x in num[0:8191]:
         print("\t13'h"+hex(cnt)+": q=8'h"+hex(ord(x))+";")
         #        8'h00: d = 4'b0000;
         cnt=cnt+1
       print("end");
       print("assign dout=q;")
       print("endmodule")
       print("module rom_"+args[0])
       print("(")
       print("input clk,")
       print("input [12:0] addr,")
       print("output [7:0] dout,")
       print("input cs );")
       print("reg [7:0] q;")
       print("always @(posedge clk) ");
       print("begin ");
       print("case (addr) ");
       cnt=0
       for x in num[8192:]:
         print("\t13'h"+hex(cnt)+": q=8'h"+hex(ord(x))+";")
         #        8'h00: d = 4'b0000;
         cnt=cnt+1

       print("end");
       print("assign dout=q;")
       print("endmodule")
if __name__ == "__main__":
   main(sys.argv[1:])

