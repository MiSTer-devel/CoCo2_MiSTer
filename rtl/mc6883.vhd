library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mc6883 is
	port
	(
		clk			: in std_logic;
		-- clk_ena 		: in std_logic;
		spd_ena		: buffer std_logic;
		turbo			: in std_logic;
		reset			: in std_logic;
		
		-- input
		addr			: in std_logic_vector(15 downto 0);
		rw_n			: in std_logic;

		-- vdg signals
		da0			: in std_logic;  -- display address 0 - 
		vh2			: in std_logic;
		hs_n			: in std_logic;
		vclk			: out std_logic;
		
		-- peripheral address selects		
		s_device_select				: out std_logic_vector(2 downto 0);
		
		-- clock generation
		clk_e			: out std_logic;
		clk_q			: out std_logic;

		-- dynamic addresses
		z_ram_addr	: out std_logic_vector(7 downto 0);

		-- ram
		ras0_n 		: out std_logic;
		cas_n			: out std_logic;
		we_n			: out std_logic;

		-- Single clock enable near end of E CLK [write enable]
		WR_CK_ENA		: out std_logic;
		
		-- debug
		dbg     		: out std_logic_vector(15 downto 0)
	);
end mc6883;

architecture SYN of mc6883 is

	subtype DivisorType is integer range 0 to 11;
	type DivisorArrayType is array (natural range <>) of DivisorType;
	-- Division variables for V0=0, V2..V1=sel
	--constant y_divisor		: DivisorArrayType(0 to 3) := (12, 3, 2, 1);
	-- Division variable for V0=1, v2..V1=sel
	--constant x_divisor		: DivisorArrayType(0 to 3) := (3, 2, 1, 1);
	constant mode_rows    : DivisorArrayType(0 to 7) := (12-1, 3-1, 3-1, 2-1, 2-1, 1-1, 1-1, 1-1);
	
  -- clocks
--	signal clk_7M15909		: std_logic;
--	signal clk_3M579545   : std_logic;
--	signal clk_1M769772   : std_logic;
--	signal clk_0M894866   : std_logic;

  -- some rising_edge pulses
	signal rising_edge_hs : std_logic;
--	signal rising_edge_q  : std_logic;
--	signal rising_edge_e  : std_logic;

  -- internal versions of pin signals
	signal we_n_s         : std_logic;

  -- video counter
	signal b_int          : std_logic_vector(15 downto 0);

	-- control register (CR)
	signal cr				: std_logic_vector(15 downto 0);
	signal sel_cr		: std_logic;
	signal turbo_d		: std_logic ;
	
	alias ty_memory_map_type: std_logic 							is cr(15);
	alias m_memory_size		: std_logic_vector(1 downto 0) 	is cr(14 downto 13);
	alias r_mpu_rate		: std_logic_vector(1 downto 0) 	is cr(12 downto 11);
	alias p_32k_page_switch : std_logic 							is cr(10);
	alias f_vdg_addr_offset : std_logic_vector(6 downto 0) 	is cr(9 downto 3);
	alias v_vdg_addr_modes 	: std_logic_vector(2 downto 0) 	is cr(2 downto 0);
	
	alias flag				: std_logic 										is addr(0);

	-- internal chipselect vectors
	signal s_ty0			: std_logic_vector(2 downto 0);
	signal s_ty1			: std_logic_vector(2 downto 0);

	signal debug    		: std_logic_vector(1 downto 0);

	shared variable yscale  : integer;

	signal	t_clks			: std_logic_vector(1 downto 0);
	signal	clk_28M_ena, clk_14M318_ena	: std_logic;

	constant spd_rate_normal	: std_logic_vector(1 downto 0) := "00";
	constant spd_rate_AD_FAST	: std_logic_vector(1 downto 0) := "01";
	constant spd_rate_FAST		: std_logic_vector(1 downto 0) := "10";

	constant FAST				: std_logic := '1';
	constant SLOW				: std_logic := '0';

	-- signal	spd_ena			: std_logic;
	signal	fast_slow		: std_logic;
	signal	spd_fast_n_slow	: std_logic;
	signal  vclk_d        : std_logic ;

	alias spd_fast			: std_logic is clk_28M_ena;
	alias spd_slow			: std_logic is clk_14M318_ena;


begin

	-- Changes to enable MPU_RATE functionallity by S.H on 6/27/24

	--	clk has been updated to be 57.272727 Mhz
	--	This process creates the two enables for the master timing loop.
	--	The master timing loop is 16 steps - so the divide by 2 will
	--	have to loop repeating at a rate of 1.78 Mhz and the divide by
	--	4 will be the normal CoCo rate of .895 Mhz

Tm:	process (clk, reset)
	begin
		if reset = '1' then
			t_clks <= (others => '0');
			clk_28M_ena <= '0';
			clk_14M318_ena <= '0';
			vclk_d <= '0' ;
			vclk <= '0' ;
		elsif rising_edge (clk) then
			clk_28M_ena <= '0';
			clk_14M318_ena <= '0';
			vclk_d <= '0' ;
			vclk <= '0' ;
			if t_clks(0) = '1' then -- this is divide by 2
				clk_28M_ena <= '1';
			end if;
			if t_clks = "11" then	-- this is divide by 4
				clk_14M318_ena <= '1';
				vclk_d <= '1' ;
				vclk <= '1' ;
			end if;
			t_clks <= t_clks + '1';
--			vclk_d <= clk_14M318_ena ; 
--			vclk <= vclk_d ;
		end if;
	end process;

	spd_fast_n_slow <=	FAST when	r_mpu_rate = spd_rate_FAST	else
						SLOW when	r_mpu_rate = spd_rate_normal else
						SLOW when	r_mpu_rate = spd_rate_AD_FAST and addr(15) = '0'	else
						SLOW when	r_mpu_rate = spd_rate_AD_FAST and addr(15 downto 5) = "11111111000"	else -- FF00-FF1F
						FAST when	r_mpu_rate = spd_rate_AD_FAST and addr(15 downto 0) = "1111111111111111" else -- FFFF
						FAST;


  -- fast_slow is the latched speed decision.  fast_slow is latched spd_fast_n_slow
  -- at state 0010

	spd_ena <= 	spd_fast	when	fast_slow = FAST	else
				spd_slow;

  --  
  -- CPU Address is valid tAD after falling edge of E
  -- CPU Read Data latched at falling edge of E
  -- CPU Write Data valid tDDW after rising edge of Q, 
  -- - until tDHW (short) after falling edge E
  --

--  vclk <= spd_ena;

  -- clock generation, ras/cas generation
  PROC_MAIN : process (clk, reset, rw_n)
    variable count : std_logic_vector(4 downto 0);
  begin
    if reset = '1' then
      --count := (others => '0');
		count := "00000";
		z_ram_addr <= (others => '0');
		clk_q <= '0';
		clk_e <= '0';
		ras0_n <= '1';
		cas_n <= '1';
		we_n_s <= '1';
		fast_slow <= SLOW;
		WR_CK_ENA <= '0';
    elsif rising_edge (clk) then
	  WR_CK_ENA <= '0';
      if spd_ena = '1' then
        we_n_s <= '1';  -- default
        -- clk_7M15909 <= count(0);
        -- clk_3M579545 <= count(1);
        -- clk_1M769772 <= count(2);
        -- clk_0M894866 <= count(3);
--        vclk <= not clk_3M579545;
        case count(3 downto 0) is
          when "0000" =>
            -- valid VDG address (row)
            -- z_ram_addr(7) is RAS1# or B(7)
            z_ram_addr <= b_int(7 downto 0);
            ras0_n <= '0';
          when "0001" =>
			 when "0010" =>
            -- valid VDG address (col)
            --case m_memory_size is
            --  when "00" =>
            --    z_ram_addr <= "00" & b_int(11 downto 6);
            --  when "01" =>
            --    z_ram_addr <= '0' & b_int(13 downto 7);
            --  when others =>
            z_ram_addr <= b_int(15 downto 8);
            --end case;
            cas_n <= '0';
				if (count(4) = '0') then fast_slow <= spd_fast_n_slow; end if;
          when "0011" =>
            clk_q <= '1';
          when "0100" =>
          when "0101" =>
            ras0_n <= '1';
          when "0110" =>
          when "0111" =>
            cas_n <= '1';
            clk_e <= '1';
          when "1000" =>
            -- valid MPU address (row)
            -- z_ram_addr(7) is RAS1# or A(7)
            z_ram_addr <= addr(7 downto 0);
            ras0_n <= '0';
          when "1001" =>
          when "1010" =>
            -- valid MPU address (col)
            -- no need to munge any signal with RAS/CAS
            --case m_memory_size is
            --  when "00" =>
            --    z_ram_addr <= "00" & addr(11 downto 6);
            --  when "01" =>
                -- z_ram_addr(7) is P or don't care
                --z_ram_addr <= p_32k_page_switch & addr(13 downto 7);
            --    z_ram_addr <= '0' & addr(13 downto 7);
            --  when others =>
            --    if ty_memory_map_type = '0' then
            --      z_ram_addr <= p_32k_page_switch & addr(14 downto 8);
            --    else
            --      z_ram_addr <= addr(15 downto 8);
            --    end if;
            --end case;
				
            z_ram_addr <= addr(15 downto 8);


            cas_n <= '0';
          when "1011" =>
            clk_q <= '0';
          when "1100" =>
          when "1101" =>
            ras0_n <= '1';
            -- drive WEn some time after mpu address is latched
            -- on the falling edge of cas_n above
            -- but in plenty of time before falling edge of E
            we_n_s <= rw_n;
          when "1110" =>
	  		WR_CK_ENA <= '1';	-- This is a single clk write enable near the end of E_CLK
          when "1111" =>
            cas_n <= '1';
            clk_e <= '0';
          when others =>
            null;
        end case;
		
		  count := count + 1;
     end if; -- clk_ena
    end if;
  end process PROC_MAIN;

  -- assign outputs
  we_n <= we_n_s;

		
  -- rising edge pulses
  process (clk, reset)
    variable old_hs : std_logic;
  --  variable old_q  : std_logic;
  --  variable old_e  : std_logic;
  begin
    if reset = '1' then
      old_hs := '0';
      rising_edge_hs <= '0';
   --   old_q := '0';
      -- rising_edge_q <= '0';
   --   old_e := '0';
      -- rising_edge_e <= '0';
    elsif rising_edge (clk) then
--f      if spd_ena = '1' then
		if (vclk_d = '1') then
--      if clk_ena = '1' then
        rising_edge_hs <= '0';
        if old_hs = '0' and hs_n = '1' then
          rising_edge_hs <= '1';
        end if;
        old_hs := hs_n;
      end if; -- clk_ena
    end if;
  end process;

  -- video address generation
  -- normally, da0 clocks the internal counter
  -- but we want a synchronous design
  -- so sample da0 each internal clock
  process (clk, reset, da0, hs_n)
    variable old_hs   : std_logic;
    variable old_da0  : std_logic;
    --variable yscale   : integer;
    variable saved_b : std_logic_vector(15 downto 0);
  begin
    if reset = '1' then
      b_int <= (others => '0');
      old_hs := '1';
      old_da0 := '1';
      yscale := 0;
      saved_b := (others => '0');
    elsif rising_edge (clk) then
  --f    if spd_ena = '1' then
		if (vclk_d = '1') then
--      if clk_ena = '1' then
        -- vertical blanking - HS rises when DA0 is high
        -- resets bits B9-15, clear B1-B8
        if rising_edge_hs = '1' and da0 = '1' then
          b_int(15 downto 9) <= f_vdg_addr_offset(6 downto 0);
          b_int(8 downto 0) <= (others => '0');
          yscale := mode_rows(conv_integer(v_vdg_addr_modes(2 downto 0)));
          saved_b := f_vdg_addr_offset(6 downto 0) & "000000000";
        -- horizontal blanking - HS low
        -- resets bits B1-B3/4
        elsif hs_n = '0' then
          if v_vdg_addr_modes(0) = '0' then
            b_int(4) <= '0';
          end if;
          b_int(3 downto 1) <= (others => '0');   
          -- coming out of HS?
          if old_hs = '1' then
            if yscale = mode_rows(conv_integer(v_vdg_addr_modes(2 downto 0))) then
              yscale := 0;
              saved_b := b_int;
            else
              yscale := yscale + 1;
              b_int <= saved_b;
            end if;
          end if;
        -- transition on da is the video clock
        elsif da0 /= old_da0 then
          b_int <= b_int + 1;
        end if;
        old_hs := hs_n;
        old_da0 := da0;
        debug <= old_hs & old_da0;
      end if; -- clk_ena
    end if;
  end process;

	-- select control register (CR)
	sel_cr <= '1' when addr(15 downto 5) = "11111111110" else '0';
	
	--
	--	Memory decode logic
	--	- combinatorial - needs to be gated
	--
	s_ty0 <= 	"010" when 	-- $FFF2-$FFFF (6809 vectors)
												-- $FFE0-$FFF1 (reserved)
												addr(15 downto 5) = "11111111111"
									else
						"111" when	-- $FFC0-$FFDF (SAM control register)
												-- $FF60-$FFBF (reserved)
												sel_cr = '1' or 
												(addr(15 downto 8) = "11111111" and (addr(7) = '1' or addr(6 downto 5) = "11"))
									else
						"110" when	-- $FF40-$FF5F (IO2)
												addr(15 downto 5) = "11111111010"
									else
						"101" when	-- $FF20-$FF3F (IO1)
												addr(15 downto 5) = "11111111001"
									else
						"100" when	-- $FF00-$FF1F (IO0)
												addr(15 downto 5) = "11111111000"
									else
						"011" when	-- $C000-$FEFF (rom2)
												addr(15 downto 14) = "11"
									else
						"010" when	-- $A000-$BFFF (rom1)
												addr(15 downto 13) = "101"
									else
						"001" when	-- $8000-$9FFF (rom0)
												addr(15 downto 13) = "100"
									else
						"000"	when	-- $0000-$7FFF (32K) RW_N=1   -> map to RAM select
												addr(15) = '0' and rw_n = '1'
									else
						---"111" when	-- $0000-$7FFF (32K) RW_N=0
						"000" when	-- $0000-$7FFF (32K) RW_N=0   -> map to RAM select
												addr(15) = '0' and rw_n = '0';

	--
	-- alternate control logic,
	-- when mapping in effect
	--
	s_ty1 <= 	s_ty0 when	-- $FF00-$FFFF
												addr(15 downto 8) = X"FF"
									else
						"000"	when	-- $0000-$FEFF (32K) RW_N=1   -> map to RAM select
												rw_n = '1'
									else
						"000" when	-- $0000-$FEFF (32K) RW_N=0   -> map to RAM select
												rw_n = '0';
	
	s_device_select <= 	s_ty0 when ty_memory_map_type = '0' else		-- if himem mapped to ROM, use s_ty0 multiplex output (normal)
				s_ty1;							-- else, also map &H8000 thru &HFEFF as RAM
				
	--
	--	Handle update of the control register (CR)
	--
	WRITE_CR : process (clk, reset, addr, rw_n)
	begin
		if reset = '1' then
			cr <= (others => '0');
			turbo_d <='0' ;
		elsif falling_edge (clk) then  
			turbo_d <= turbo ;
			if (turbo /= turbo_d) then 
				r_mpu_rate(0) <= turbo ;
			end if;
         if spd_ena = '1' then
--			if clk_ena = '1' then
			if sel_cr = '1' and we_n_s = '0' then
				case addr(4 downto 1) is
				when "0000" =>
					v_vdg_addr_modes(0) <= flag;
				when "0001" =>
					v_vdg_addr_modes(1) <= flag;
				when "0010" =>
					v_vdg_addr_modes(2) <= flag;
				when "0011" =>
					f_vdg_addr_offset(0) <= flag;
				when "0100" =>
					f_vdg_addr_offset(1) <= flag;
				when "0101" =>
					f_vdg_addr_offset(2) <= flag;
				when "0110" =>
					f_vdg_addr_offset(3) <= flag;
				when "0111" =>
					f_vdg_addr_offset(4) <= flag;
				when "1000" =>
					f_vdg_addr_offset(5) <= flag;
				when "1001" =>
					f_vdg_addr_offset(6) <= flag;
				when "1010" =>
					p_32k_page_switch <= flag;
				when "1011" =>		-- &HFFD6/D7 - the "high speed poke"  (D7 enables "high speed", D6 disables)
					r_mpu_rate(0) <= flag;
				when "1100" =>
					r_mpu_rate(1) <= flag;
				when "1101" =>
					m_memory_size(0) <= flag;
				when "1110" =>
					m_memory_size(1) <= flag;
				when others =>    -- "1111"   &HFFDE/DF
					ty_memory_map_type <= flag;		-- this flag maps ROM or RAM to the top half of memory.  FFDE = ROM, FFDF = RAM
				end case;
			end if;
		  end if; -- clk_ena
		end if;
	end process WRITE_CR;

  -- for hexy display, for example
  dbg <= cr;
  
end SYN;
