defmodule Airplane do
  def start pid_line do
    time = Time.utc_now
    airplane = %{
      ref_line: pid_line,
      pid: self(),
      created: %{ utc: time, formatted: "#{time.hour}:#{time.minute}:#{time.second}" },
      events: [%{status: Enum.random([:TO_TAKEOFF, :TO_LANDING]), utc: time}]
      # LANDING, TAKEOFF, AROUND, WAITING
    }

    send(pid_line, { :REQUEST, airplane })
    airplane(airplane)
  end

  def airplane(state) do
    command_analysis(List.last(state[:events])[:status], state)
    receive do
      :stay_turn ->
        send(state[:ref_line], {:WAITING_NEW_INSTRUCTION, state})
        airplane(state)
      {:command, assignment} ->
        send(state[:ref_line], :OK)
        airplane(assignment)
      :processed ->
        Process.exit(state[:pid], :normal)
      :info ->
        send(state[:ref_line], {:INFO, state})
        airplane(state)
    end
  end


  def command_analysis command, airplane do
    if command === :LANDING || command === :TAKEOFF do
      IO.puts "Process #{command}"
      IO.inspect(airplane[:pid])
      :timer.sleep(10000)
      IO.puts "Process done #{command}"
      IO.inspect(airplane[:pid])
      send(airplane.ref_line, {:RESPONSE, :DONE, airplane} )
    end
  end

  def report do
    report_time = []
  end
end
