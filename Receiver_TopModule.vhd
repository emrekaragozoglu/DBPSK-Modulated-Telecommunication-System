----------------------------------------------------------------------------------
-- Group				: 9
 
-- Engineer			: Emre Karagozoglu 21002397
 
-- Create Date		: 16:32:12 24/12/2015 

-- Module Name		: TopModule - Behavioral 

-- Project Name	: EEE495

-- Description		: Rx Part

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.std_logic_arith.all;
--use IEEE.std_logic_signed.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity TopModule is
	port ( CLK			: in  std_logic;
			 SCLK			: out std_logic;
			 CS			: out std_logic;
			 SDATA		: in  std_logic;
			 VIN			: out std_logic;
			 START_READ	: in  std_logic;
			 --LEDS			: out std_logic_vector(7 downto 0);
			 --LED1  		: out std_logic:='0';
			 LED2  		: out std_logic:='0';
			 LED3  		: out std_logic:='0';
			 OUTPIN  	: out std_logic:='0';
			 TXD			: out std_logic
			 );
end TopModule;

architecture Behavioral of TopModule is

component rs232 
port (   clk                 :   in  std_logic;  -- 50 Mhz clock
         tx_start            :   in  std_logic;  -- transmit (tx) enable pin
         test_mode           :   in  std_logic;  -- test mode switch
         DATAIN              :   in  std_logic_vector (7 downto 0); -- to be transmitted data vector
         txd                 :   out std_logic -- serial out pin
			);
end component;

signal data:std_logic_vector(11 downto 0):= (others=>'0');
signal clk125:std_logic:='0';
signal clk8:std_logic:='0';
signal clk1hz : std_logic :='0';
signal clk500khz : std_logic :='0';
signal css:std_logic:='1';
signal res_bit : std_logic:='0';
signal tx_start:std_logic:='0'; 
signal test_mode:std_logic:='0';
signal DATAIN:std_logic_vector (7 downto 0):=(others=>'0');
signal flag:std_logic:='0';
signal RAMwrite_done:std_logic:='0';
signal threshold:std_logic:='0';

type receiver is array (1 to 125) of std_logic_vector(7 downto 0);
signal received: receiver;

type receiver2 is array (1 to 1) of std_logic_vector(7 downto 0);
signal received2: receiver2;

type decisionarray is array (1 to 1000) of std_logic_vector(7 downto 0);
signal decisions: decisionarray;


begin

RS232UNIT : rs232
  PORT MAP (
			clk=>clk,
			tx_start=>tx_start,			
			test_mode=>test_mode,			
			DATAIN=>DATAIN,	
			txd=>txd	
 ); 
 
--tx_start<=RAMwrite_done;
--tx_start<=START_READ;
	
CS<=css;
VIN <= '1';


--Clock Divider Process
process(CLK)
variable count: integer range 0 to 1;
variable count8: integer range 1 to 3125;
variable count1hz: integer range 1 to 25000000;
variable count500khz: integer range 1 to 50;
	begin
		if rising_edge(CLK) then 
			if(count = 1) then
				clk125 <= NOT(clk125);
				SCLK <= clk125;
				count:=0;
			else
				count := (count+1);
			end if;		
			if(count8 = 3125) then
				clk8 <= NOT(clk8);
				count8:=1;
			else
				count8 := (count8+1);
			end if;
			if(count1hz = 25000000) then
				clk1hz <= NOT(clk1hz);
				count1hz:=1;
			else
				count1hz := (count1hz+1);
			end if;	
			if(count500khz = 50) then
				clk500khz <= NOT(clk500khz);
				count500khz:=1;
			else
				count500khz := (count500khz+1);
			end if;

		end if;
end process;

--ADC Process
process(clk125)
	variable count2: integer range 0 to 31:=0;
	begin 
	if rising_edge(clk125) then
		if START_READ='1' then
			count2:= count2+1;
			if count2 = 1 then
				css <= '0';
			elsif count2 > 5 and count2 < 18  then
				data (17-count2) <= SDATA;
			elsif count2 = 18 then
				css <= '1';
			elsif count2 = 25 then
				--LEDS<=data(11 downto 4);
				if data(11 downto 4)>"00001010" then
					threshold<='1';
				end if;
				if threshold='1' then
					received2(1)<=data(11 downto 4);
				end if;
				count2 := 0;
			end if;
		end if;
	end if;
end process;

--Demodulator Process
process(clk500khz)
variable index: integer range 1 to 126:=1;
variable indexd: integer range 1 to 1001:=1;
variable sum: integer range -17000000 to 17000000;
variable flag: integer range 0 to 1:=0;
begin 
	if rising_edge(clk500khz) then
		if START_READ='1' then
			--Placing the samples into the received array
			if index < 126  and flag = 1 then
				sum := sum + (to_integer(signed(received(index))-128))*to_integer((signed(received2(1))-128));
				received(index) <= received2(1);
				index:=index + 1;
			elsif index <126 and flag = 0 then
				received(index) <= received2(1);
				index := index +1;	
			elsif index=126 then
				index:=1;
				flag := 1;
				
				if indexd<1001 then
					if sum<=0 then
						decisions(indexd)<="00000000";
						res_bit<='0';
						LED3 <= '0';
						OUTPIN <= '0';
					elsif sum>0 then
						decisions(indexd)<="00000001";
						res_bit<='1';
						LED3 <= '1';
						OUTPIN <= '1';
					end if;
					indexd:=indexd+1;
				elsif indexd=1001 then
					indexd:=1;
					RAMwrite_done<='1';
					tx_start<='1';
				end if;
				
				sum:=0;
			end if;

		end if;
	end if;
end process;

--RS232 Process
process(clk8)
variable index: integer range 1 to 1001:=1;
begin
	if rising_edge(clk8) then
		if RAMwrite_done='1' then
			if index<1001 then
				DATAIN<=decisions(index);
				index:=index+1;
			else
				index:=1;
			end if;
		end if;
	end if;
end process;

end Behavioral;
