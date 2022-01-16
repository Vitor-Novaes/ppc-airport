

defmodule Airtraffic do
  import Airplane
  import Line
  @moduledoc """
  Documentation for `Airport`.

  The env: One line in airport for airplanes
  Mutual exclusion of the use by one airplate

  - Airplane take-off needs 5 seconds
  - Airplane landing needs 10 seconds
  - Airplane in take-off queue needs wait more 5 seconds interval to use line
  - Permit only 3 airplanes waiting for take-off
  - Priority for landing airplanes, case queue for take-off is full and landing
  airplane able to waiting, the priority has change
  - Around timeout 30 seconds
  - Airplane will be create each 7 seconds, randomly for landing or take-off


  Log:
    - Time created
    - Status
    - Time register when change status

  Elements:
    - Priority clause
    - Queue manager
    -
  """

  def generate_airplane pid_line do
    IO.puts 'Creating airplane'
    pid_airplane = spawn_link(Airplane, :start, [pid_line])
    send(pid_airplane, :set)
    :timer.sleep(7000)

    generate_airplane pid_line
  end

  def start_line do
    pid_line = spawn_link(Line, :start, [])
    IO.inspect pid_line
    generate_airplane pid_line
  end
end

Airtraffic.start_line()
