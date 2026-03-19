# Add this check to the running service
Code.eval_string("""
defmodule ConfigCheck do
  def run do
    config = SymphonyElixir.Config.settings!()
    IO.puts("Lifecycle enabled: #{inspect(config.lifecycle.enabled)}")
    IO.puts("Lifecycle stages: #{length(config.lifecycle.stages)}")
  end
end
""")

defmodule ConfigCheck do
  def run do
    IO.puts("Testing...")
  end
end

ConfigCheck.run()
