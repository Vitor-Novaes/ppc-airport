defmodule Airplane do

  @doc """
    Create the base data message information about the plane
    and initialize the comunication with the tower process
  """
  def start pid_lane, status do
    time = Time.utc_now

    airplane = %{
      ref_lane: pid_lane,
      pid: self(),
      created: %{ utc: time, formatted: "#{time.hour}:#{time.minute}:#{time.second}" },
      events: [%{status: status, utc: time, diff: 0}], # LANDING, TAKEOFF, AROUND, WAITING possible status
      total_time: nil
    }

    send(pid_lane, { :REQUEST, airplane })
    airplane(airplane)
  end

  @doc """
    Recursive function able to capture tower's comunication
  """
  def airplane(state) do
    command_analysis(List.last(state[:events])[:status], state)
    receive do
      :stay_turn -> # when the tower wants to take a new action
        send(state[:ref_lane], {:WAITING_NEW_INSTRUCTION, state})
        airplane(state)
      {:command, assignment} -> # when the tower gives a action
        send(state[:ref_lane], :OK)
        airplane(assignment)
      :processed -> # when all it's done
        Process.exit(state[:pid], :normal)
      :info -> # when the tower wants some information
        send(state[:ref_lane], {:INFO, state})
        airplane(state)
    end
  end

  @doc """
    Time action and send message when all it's done
  """
  def command_analysis command, airplane do
    if command === :LANDING || command === :TAKEOFF do
      :timer.sleep(10000)
      send(airplane.ref_lane, {:RESPONSE, :DONE, airplane} )
    end
  end
end
