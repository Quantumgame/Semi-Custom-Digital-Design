library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity multn_seq is
   generic(NBITS : natural); 
   port(
      signal clk, rst_b : in std_logic;
      signal opa : in std_logic_vector(NBITS-1 downto 0);
      signal opb : in std_logic_vector(NBITS-1 downto 0);
      signal cmd : in std_logic;
      signal done : out std_logic;
      signal mres : out std_logic_vector(2*NBITS-1 downto 0)
   );
   
end entity multn_seq;

architecture RTL of multn_seq is
   
   -- states  
   type state_type is (ST_START, ST_LOAD, ST_OP);
   signal state_reg, state_next : state_type; 
   
   -- data registers
   signal  mres_next, mres_reg  : signed(2*NBITS+2 downto 0);  
   signal count_next, count_reg : unsigned(4 downto 0);  
   
   --internal status signals
   signal mres_out  : signed(2*NBITS+2 downto 0);  
   signal count_out : unsigned(4 downto 0); 
   signal fin : std_logic;
   
   -- functional unit outputs     
   signal a_p : unsigned(1 downto 0);
   
   -- signal for booth algorithm
   signal mplier : signed(2*NBITS+2 downto 0);  
   signal opa_r_next, opa_r_reg : std_logic_vector(NBITS-1 downto 0);
   
begin -- architecture 

    -- (CU) state register  
   CU_REG: process(clk, rst_b) is
   begin    
      if rst_b = '0' then
           state_reg <= ST_START;
      elsif rising_edge(clk) then
           state_reg <= state_next;
      end if;   
   end process CU_REG; 

    -- next state logic 
    CU_NSL : process(state_reg, cmd, fin)  
    begin 
    state_next <= state_reg;
        
        case state_reg is 
            when ST_START => if cmd = '1' then 
                                 state_next <= ST_LOAD;
                             else
                                 state_next <= ST_START;
                             end if;
            when ST_LOAD => state_next <= ST_OP;  
            when ST_OP => if fin = '1' then  
                              state_next <= ST_START;  
                          end if;
        end case;                   
                                       
    end process CU_NSL;  
    
    -- output logic
    CU_OL : done <= '1' when state_reg = ST_START else '0';
                                     
    -- data registers 
    DPU_REG : process(clk, rst_b)
    begin
      if rst_b = '0' then 
         count_reg <= (others => '0');
         mres_reg  <= (others => '0'); 
         opa_r_reg <= (others => '0');
      elsif rising_edge(clk) then
         count_reg <= count_next;
         mres_reg <= mres_next;
         opa_r_reg <= opa_r_next;
      end if;           
    
   end process DPU_REG;
   
   -- status signals 
   fin <= '1' when count_next = NBITS/2 else '0';   
      
    -- routing mux 
    DPU_RMUX : process(state_reg, opa, opb, count_out, mres_out, count_reg, mres_reg) 
    begin
      count_next <= count_reg;
      mres_next <= mres_reg;
      opa_r_next <= opa_r_reg;
      case state_reg is 
         when ST_START => null;
         when ST_LOAD => 
                         opa_r_next <= opa;
                         mres_next <= ((NBITS+1 downto 0 => '0') & signed(opb) & '0');
                         count_next <= (others => '0');
                                                
         when ST_OP =>  count_next <= count_out;
                        mres_next <= mres_out;
                         
      end case;   
    end process DPU_RMUX;    
    
  
   -- functional units 
   count_out <= count_reg + 1;                          -- counter 
   CU_OL1 : a_p <= "00" when signed(opa_r_reg) >= 0 else "11";

   with mres_reg(2 downto 0) select
   mplier <=
      (signed(a_p) & signed(opa_r_reg) & (NBITS downto 0 => '0'))                   when "001" | "010", -- 1 * Multiplicand
      (signed(a_p) & shift_left(signed(opa_r_reg),1) & (NBITS downto 0 => '0'))     when "011",         -- 2 * Multiplicand
      (-(signed(a_p) & shift_left(signed(opa_r_reg),1)) & (NBITS downto 0 => '0'))  when "100",         -- -2 * Multiplicand
      (-(signed(a_p) & signed(opa_r_reg)) & (NBITS downto 0 => '0'))                when "101" | "110", -- -1 * Multiplicand  
      (2*NBITS+2 downto 0 => '0')   when others;   
      
   mres_out <= shift_right(mres_reg + mplier, 2);       

   mres <= std_logic_vector(mres_reg(2*NBITS downto 1));


end architecture RTL;

