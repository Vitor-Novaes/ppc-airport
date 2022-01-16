# The tower
defmodule Line do
  def start do
    line = %{
      around: [],
      wait: [],
      busy: false,
    }

    listen(line)
  end

  def listen line do
    receive do
      {:REQUEST, airplane} ->
        { assignment, line_updated } = request_analysis(airplane, line)
        send(airplane[:pid], {:command, assignment})
        IO.inspect assignment
        IO.inspect line_updated
        listen(line_updated)
      {:RESPONSE, :DONE, airplane} ->
        send(airplane[:pid], :processed)
        line = Map.put(line, :busy, false)
        IO.inspect line
        check_priority(line)
        IO.puts('Im return the LINE')
        listen(line)
      {:WAITING_NEW_INSTRUCTION, airplane} ->
        { assignment, line } = priority_command(airplane, line)
        send(airplane[:pid], {:command, assignment})
        listen(line)
    end
  end

  def request_analysis airplane, line do
    case List.last(airplane[:events])[:status] do
      :TO_TAKEOFF ->
        unless line[:busy] do
          cond do
            length(line[:wait]) == 0 && length(line[:around]) == 0 ->
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :TAKEOFF, utc: Time.utc_now}]))
              line = Map.put(line, :busy, true)
              { airplane, line }

            length(line[:wait]) > 0 || length(line[:around]) > 0 ->
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :WAITING, utc: Time.utc_now}]))
              line = Map.put(line, :wait, Enum.concat(line[:wait], [airplane[:pid]]))
              { airplane, line }
          end

        else
          airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :WAITING, utc: Time.utc_now}]))
          line = Map.put(line, :wait,  Enum.concat(line[:wait], [airplane[:pid]]))
          { airplane, line }
        end
      :TO_LANDING ->
        unless line[:busy] do
          cond do
            length(line[:wait]) == 0 && length(line[:around]) == 0 ->
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :LANDING, utc: Time.utc_now}]))
              line = Map.put(line, :busy, true)
              { airplane, line }

            length(line[:wait]) > 0 || length(line[:around]) > 0 ->
              airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :AROUND, utc: Time.utc_now}]))
              line = Map.put(line, :around,  Enum.concat(line[:around], [airplane[:pid]]))
              { airplane, line }
          end

        else
          airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :AROUND, utc: Time.utc_now}]))
          line = Map.put(line, :around,  Enum.concat(line[:around], [airplane[:pid]]))
          { airplane, line }
        end
    end
  end

  def check_priority line do
    IO.inspect('check airplane wait and around priority')

    cond do
      length(line[:around]) != 0 && line[:busy] == false ->
        send(List.first(line[:around]), :info)
        receive do
          { :INFO, state } ->
            IO.inspect Time.diff(Time.utc_now, List.last(state[:events])[:utc])
            cond do
              Time.diff(Time.utc_now, List.last(state[:events])[:utc]) >= 15 -> send(List.first(line[:around]), :stay_turn)
              length(line[:wait]) >= 3 -> send(List.first(line[:wait]), :stay_turn)
              length(line[:around]) >= 3 -> send(List.first(line[:around]), :stay_turn)
              length(line[:wait]) == 0 -> send(List.first(line[:around]), :stay_turn)
              length(line[:wait]) != 0 -> send(List.first(line[:wait]), :stay_turn)
            end
        end
      length(line[:wait]) != 0 && line[:busy] == false -> send(List.first(line[:wait]), :stay_turn)
      true -> IO.puts 'Line busy or not airplane in the traffic'
    end
  end

  def priority_command airplane, line do
    IO.puts('priority requested')
    case List.last(airplane[:events])[:status] do
      :WAITING ->
        airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :TAKEOFF, utc: Time.utc_now}]))
        line = Map.put(line, :busy, true)
        line = Map.put(line, :wait, List.delete_at(line[:wait], 0))
        { airplane, line }
      :AROUND ->
        airplane = Map.put(airplane, :events, Enum.concat(airplane[:events], [%{status: :LANDING, utc: Time.utc_now}]))
        line = Map.put(line, :busy, true)
        line = Map.put(line, :around, List.delete_at(line[:around], 0))
        { airplane, line }
    end
  end

end
