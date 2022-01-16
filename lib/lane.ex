# The tower
defmodule Lane do
  @doc """
    Create the base data message information from tower
    and initialize the comunication with the airplanes
  """
  def start do
    lane = %{
      around: [],
      wait: [],
      busy: false,
      by: nil,
    }
    report = []

    listen(lane, report)
  end

  @doc """
    Recursive function able to capture airplane's comunication
  """
  def listen lane, report do
    receive do
      {:REQUEST, airplane} -> # when airplane tries some action
        { assignment, lane_updated } = request_analysis(airplane, lane)
        send(airplane[:pid], {:command, assignment})
        IO.inspect lane_updated
        listen(lane_updated, report)
      {:RESPONSE, :DONE, airplane} -> # when airplane reply your action
        { airplane, report }= register_airplane(airplane, report)
        send(airplane[:pid], :processed)
        lane = Map.put(lane, :busy, false)
        lane = Map.put(lane, :by, nil)
        IO.puts 'Lane cleared'
        check_priority(lane, report)
        listen(lane, report)
      {:WAITING_NEW_INSTRUCTION, airplane} -> # when airplane able to new action
        { assignment, lane } = priority_command(airplane, lane)
        IO.inspect lane
        send(airplane[:pid], {:command, assignment})
        listen(lane, report)
    end
  end

  @doc """
    First Call polices when trie takeoff or landing
  """
  def request_analysis airplane, lane do
    case List.last(airplane[:events])[:status] do
      :TO_TAKEOFF ->
        unless lane[:busy] do
          cond do
            length(lane[:wait]) == 0 && length(lane[:around]) == 0 -> # when lane up is clean
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :TAKEOFF, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
              lane = Map.put(lane, :busy, true)
              lane = Map.put(lane, :by, airplane[:pid])
              { airplane, lane }

            length(lane[:wait]) > 0 || length(lane[:around]) > 0 ->  # when least one lane up has more one plane
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :WAITING, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
              lane = Map.put(lane, :wait, Enum.concat(lane[:wait], [airplane[:pid]]))
              { airplane, lane }
          end

        else
          airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :WAITING, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
          lane = Map.put(lane, :wait,  Enum.concat(lane[:wait], [airplane[:pid]]))
          { airplane, lane }
        end
      :TO_LANDING ->
        unless lane[:busy] do
          cond do
            length(lane[:wait]) == 0 && length(lane[:around]) == 0 -> # when lane up is clean
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :LANDING, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
              lane = Map.put(lane, :busy, true)
              lane = Map.put(lane, :by, airplane[:pid])
              { airplane, lane }

            length(lane[:wait]) > 0 || length(lane[:around]) > 0 -> # when least one lane up has more one plane
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :AROUND, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
              lane = Map.put(lane, :around,  Enum.concat(lane[:around], [airplane[:pid]]))
              { airplane, lane }
          end

        else
          airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :AROUND, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
          lane = Map.put(lane, :around,  Enum.concat(lane[:around], [airplane[:pid]]))
          { airplane, lane }
        end
    end
  end

  @doc """
    Check policies for priority airplanes for action
  """
  def check_priority lane, report do
    cond do
      length(lane[:around]) != 0 && lane[:busy] == false -> # when there are planes in turn around
        send(List.first(lane[:around]), :info)
        receive do
          { :INFO, state } ->
            cond do
              Time.diff(Time.utc_now, List.last(state[:events])[:utc]) >= 15 -> send(List.first(lane[:around]), :stay_turn) # 1 - Fuel
              length(lane[:wait]) >= 3 -> send(List.first(lane[:wait]), :stay_turn) # 2 - Tax lane up
              length(lane[:around]) >= 2 -> send(List.first(lane[:around]), :stay_turn) # 3 - Around lane up
              length(lane[:wait]) == 0 -> send(List.first(lane[:around]), :stay_turn) # 4 - Around priority lane up
              length(lane[:wait]) != 0 -> send(List.first(lane[:wait]), :stay_turn) # 5 - Tax priority lane up
            end
        end
      length(lane[:wait]) != 0 && lane[:busy] == false -> send(List.first(lane[:wait]), :stay_turn)
      true -> IO.inspect report
    end
  end


  @doc """
    Priority command to airplane
  """
  def priority_command airplane, lane do
    case List.last(airplane[:events])[:status] do
      :WAITING ->
        airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :TAKEOFF, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
        lane = Map.put(lane, :busy, true)
        lane = Map.put(lane, :by, airplane[:pid])
        lane = Map.put(lane, :wait, List.delete_at(lane[:wait], 0))
        { airplane, lane }
      :AROUND ->
        airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :LANDING, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
        lane = Map.put(lane, :busy, true)
        lane = Map.put(lane, :by, airplane[:pid])
        lane = Map.put(lane, :around, List.delete_at(lane[:around], 0))
        { airplane, lane }
    end
  end

  def register_airplane airplane, report do
    airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :DONE, utc: Time.utc_now, diff: Time.diff(Time.utc_now, List.last(airplane[:events])[:utc])}]))
    total_time = airplane[:events] |> Enum.map(fn item -> item.diff end) |> Enum.sum()
    airplane = Map.put(airplane, :total_time, total_time)
    report = List.insert_at(report, 0, airplane)
    {airplane, report}
  end

end
