

defmodule Airtraffic do
  import Airplane
  import Lane
  @moduledoc """
  Documentation for `Airport`.

  The env: One lane in airport for airplanes
  Mutual exclusion of the use by one airplate

  - Airplane take-off needs 5 seconds
  - Airplane landing needs 10 seconds
  - Airplane in take-off queue needs wait more 5 seconds interval to use lane
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

  @doc """
   Randomly generates the planes in an interval of 8 seconds,
   in a total of 18 planes whose 9 of them are in the air and 9 of them
   on the ground
  """
  def generate_airplane pid_lane, x do
    takeoff =  0
    landing = 0

    if x, do: Enum.each(0..17, fn(_x) ->
      status = Enum.random([:TO_TAKEOFF, :TO_LANDING])

      if landing > 9, do: status = :TO_TAKEOFF
      if takeoff > 9, do: status = :TO_LANDING # bad
      if status == :TO_LANDING, do: landing = landing + 1, else: takeoff = takeoff + 1

      # Create PID process
      pid_airplane = spawn_link(Airplane, :start, [pid_lane, status])
      :timer.sleep(8000)
    end)

    generate_airplane pid_lane, false
  end

  @doc """
   Creates the process lane who manage the air traffic
  """
  def start_lane do
    pid_lane = spawn_link(Lane, :start, [])
    generate_airplane pid_lane, true
  end
end

Airtraffic.start_lane()
