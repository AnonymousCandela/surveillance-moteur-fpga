library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.package_constants.all;

entity tb_threshold_classifier is
end tb_threshold_classifier;

architecture Behavioral of tb_threshold_classifier is

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '1';

    signal rpm_in      : unsigned(15 downto 0);
    signal current_in  : unsigned(15 downto 0);

    signal frame_valid : std_logic := '0';

    signal state_out   : motor_state_t;

begin

    --------------------------------------------------------------------
    -- Horloge 50 MHz
    --------------------------------------------------------------------
    clk <= not clk after 10 ns;

    --------------------------------------------------------------------
    -- Instanciation du module à tester
    --------------------------------------------------------------------
    DUT : entity work.threshold_classifier
        port map(
            clk         => clk,
            reset       => reset,
            rpm_in      => rpm_in,
            current_in  => current_in,
            frame_valid => frame_valid,
            state_out   => state_out
        );

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
       process
    begin

        reset <= '1';
        rpm_in <= (others => '0');
        current_in <= (others => '0');
        frame_valid <= '0';

        wait for 100 ns;
        reset <= '0';

        --------------------------------------------------------
        -- Trois mesures NORMAL
        --------------------------------------------------------
        for i in 1 to 3 loop
            rpm_in     <= to_unsigned(228, 16);
            current_in <= to_unsigned(530, 16);

            frame_valid <= '1';
            wait for 20 ns;

            frame_valid <= '0';
            wait for 100 ns;
        end loop;

        --------------------------------------------------------
        -- Trois mesures DEGRADE
        --------------------------------------------------------
        for i in 1 to 3 loop
            rpm_in     <= to_unsigned(180, 16);
            current_in <= to_unsigned(900, 16);

            frame_valid <= '1';
            wait for 20 ns;

            frame_valid <= '0';
            wait for 100 ns;
        end loop;

        --------------------------------------------------------
        -- Trois mesures FAULT
        --------------------------------------------------------
        for i in 1 to 3 loop
            rpm_in     <= to_unsigned(40, 16);
            current_in <= to_unsigned(2300, 16);

            frame_valid <= '1';
            wait for 20 ns;

            frame_valid <= '0';
            wait for 100 ns;
        end loop;

        wait;
    end process;
	 end Behavioral;