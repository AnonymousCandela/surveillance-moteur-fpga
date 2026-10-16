library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.package_constants.all;

entity top_motor_classifier is
    Port (
        clk   : in  std_logic;
        key_reset_n : in std_logic;
		  

        rx    : in  std_logic;
        tx    : out std_logic
    );
end top_motor_classifier;
architecture Structural of top_motor_classifier is

	 signal reset_internal : std_logic;
	 
    signal uart_data       : std_logic_vector(7 downto 0);
    signal uart_ready      : std_logic;

    signal rpm_value       : unsigned(15 downto 0);
    signal current_value   : unsigned(15 downto 0);
    signal frame_valid_sig : std_logic;

    signal motor_state     : motor_state_t;

    signal tx_busy         : std_logic;

begin

	reset_internal <= not key_reset_n;
    --------------------------------------------------------------------
    -- Réception UART : Arduino vers FPGA
    --------------------------------------------------------------------
    U_UART_RX : entity work.uart_rx
        port map (
            clk        => clk,
            reset => reset_internal,
            rx         => rx,
            data_out   => uart_data,
            data_ready => uart_ready
        );

    --------------------------------------------------------------------
    -- Décodage de la trame reçue
    --------------------------------------------------------------------
    U_FRAME_HANDLER : entity work.rx_frame_handler
        port map (
            clk         => clk,
            reset => reset_internal,
            data_in     => uart_data,
            data_ready  => uart_ready,
            rpm_out     => rpm_value,
            current_out => current_value,
            frame_valid => frame_valid_sig
        );

    --------------------------------------------------------------------
    -- Classification du moteur
    --------------------------------------------------------------------
    U_CLASSIFIER : entity work.threshold_classifier
        port map (
            clk         => clk,
            reset => reset_internal,
            rpm_in      => rpm_value,
            current_in  => current_value,
            frame_valid => frame_valid_sig,
            state_out   => motor_state
        );

    --------------------------------------------------------------------
    -- Transmission de l’état vers l’Arduino
    --------------------------------------------------------------------
    U_UART_TX : entity work.uart_tx
        port map (
            clk      => clk,
            reset => reset_internal,
            state_in => motor_state,
            send     => frame_valid_sig,
            tx       => tx,
            busy     => tx_busy
        );

end Structural;